#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/nonet-workflow-contract.XXXXXXXX")"
cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

expect_failure() {
  local label=$1
  shift
  if "$@" >"$test_root/$label.out" 2>&1; then
    printf 'assert-macos-signing-workflows.test: %s unexpectedly passed\n' "$label" >&2
    exit 1
  fi
  printf '%s=rejected\n' "$label"
}

make_fixture() {
  local name=$1
  local fixture="$test_root/$name"
  mkdir -p "$fixture"
  cp -R "$ROOT/.github" "$fixture/.github"
  printf '%s\n' "$fixture"
}

bash "$ROOT/.github/scripts/assert-macos-signing-workflows.sh" >/dev/null
echo 'current-contract=passed'

quoted_push_fixture="$(make_fixture quoted-push)"
ruby - "$quoted_push_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = "on:\n  workflow_dispatch:"
replacement = "on:\n  \"push\":\n  workflow_dispatch:"
abort "quoted-push fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure quoted-push \
  bash "$quoted_push_fixture/.github/scripts/assert-macos-signing-workflows.sh"

checkout_action_fixture="$(make_fixture checkout-action)"
ruby - "$checkout_action_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
job_start = text.index("\n  package-mac:") or abort "package-mac fixture anchor missing"
job_end = text.index(/^  [[:alnum:]_-]+:/, job_start + "\n  package-mac:".length) || text.length
job = text[job_start...job_end]
anchor = <<'YAML'
      - name: Check out private Nonet source
        uses: actions/checkout@v6
        with:
          repository: moonaries90/nonet
YAML
replacement = anchor.sub("uses: actions/checkout@v6", "uses: attacker/checkout@v6")
abort "checkout-action fixture anchor missing" unless job.sub!(anchor, replacement)
text[job_start...job_end] = job
File.binwrite(path, text)
RUBY
expect_failure unexpected-checkout-action \
  bash "$checkout_action_fixture/.github/scripts/assert-macos-signing-workflows.sh"

comment_bypass_fixture="$(make_fixture comment-bypass)"
ruby - "$comment_bypass_fixture/.github/scripts/production-macos-signing.sh" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = <<'CODE'
  [[ "$actual_sha" == "$main_sha" ]] \
    || fail "checked-out source is not the authenticated origin/main commit"
CODE
replacement = <<'CODE'
  : # [[ "$actual_sha" == "$main_sha" ]]
CODE
abort "comment-bypass fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure comment-only-exact-main \
  bash "$comment_bypass_fixture/.github/scripts/assert-macos-signing-workflows.sh"

echo 'assert-macos-signing-workflows.test: passed'
