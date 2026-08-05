#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fail() {
  echo "assert-macos-signing-workflows: $*" >&2
  exit 1
}

publishing_workflows=()
while IFS= read -r workflow; do
  publishing_workflows+=("$workflow")
done < <(grep -El 'gh release (create|upload)' "$ROOT"/.github/workflows/*.yml)
(( ${#publishing_workflows[@]} > 0 )) || fail "no publishing workflow was found"

for workflow in "${publishing_workflows[@]}"; do
  grep -Fq 'environment: production-signing' "$workflow" \
    || fail "publishing workflow lacks the production-signing Environment: $workflow"
  grep -Fq 'NONET_REQUIRE_STABLE_MACOS_SIGNING: "1"' "$workflow" \
    || fail "publishing workflow lacks the stable-signing guard: $workflow"
  grep -Fq 'production-macos-signing.sh setup' "$workflow" \
    || fail "publishing workflow bypasses centralized signing setup: $workflow"
  grep -Fq 'verify-macos-desktop-package.sh' "$workflow" \
    || fail "publishing workflow bypasses mounted-package verification: $workflow"
done

if grep -Eq 'NONET_MACOS_SIGNING_(P12_B64|P12_PASSWORD)' \
  "$ROOT/.github/workflows/build-macos.yml"; then
  fail "non-publishable build-macos must not access stable signing secrets"
fi

release_workflow="$ROOT/.github/workflows/release-desktop.yml"
regression_job="$(sed -n '/^  macos-signing-regression:/,/^  [[:alnum:]_-]*:/p' \
  "$release_workflow")"
production_job="$(sed -n '/^  package-mac:/,/^  [[:alnum:]_-]*:/p' \
  "$release_workflow")"
active_contract_step="$(sed -n \
  '/      - name: Verify active stable signing identity without keychain mutation/,/      - name: Package macOS desktop/p' \
  "$release_workflow")"

grep -Fq 'package-desktop-signing.test.sh' <<<"$regression_job" \
  || fail "synthetic keychain regression suite is not isolated in its prerequisite job"
grep -Fq 'NONET_TEST_CI_SYNTHETIC_KEYCHAIN_ONLY: "1"' <<<"$regression_job" \
  || fail "hosted-runner synthetic identity mode is not confined to the regression job"
if grep -Eq 'environment: production-signing|NONET_MACOS_SIGNING_(P12_B64|P12_PASSWORD)|production-macos-signing.sh setup' \
  <<<"$regression_job"; then
  fail "synthetic keychain regression job can access or mutate production signing state"
fi
grep -Fq 'macos-signing-regression' <<<"$production_job" \
  || fail "production macOS package job does not require the isolated regression suite"
grep -Fq 'verify-active-macos-signing-identity.sh' <<<"$active_contract_step" \
  || fail "production signing contract does not use the active-identity verifier"
if grep -Fq 'package-desktop-signing.test.sh' <<<"$production_job"; then
  fail "production signing job runs the destructive synthetic keychain suite"
fi
if grep -Fq 'NONET_TEST_CI_SYNTHETIC_KEYCHAIN_ONLY' <<<"$production_job"; then
  fail "production signing job enables the hosted synthetic lifecycle mode"
fi
grep -Fq 'signing-evidence-macos.txt' <<<"$production_job" \
  || fail "production macOS job does not persist non-secret signing evidence"
grep -Fq 'dmgSha256' <<<"$production_job" \
  || fail "production macOS evidence does not bind the DMG digest"

echo "assert-macos-signing-workflows: passed"
