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

echo "assert-macos-signing-workflows: passed"
