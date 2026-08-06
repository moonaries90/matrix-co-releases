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

spaced_push_fixture="$(make_fixture spaced-push)"
ruby - "$spaced_push_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = "on:\n  workflow_dispatch:"
replacement = "on:\n  push :\n  workflow_dispatch:"
abort "spaced-push fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure spaced-colon-push \
  bash "$spaced_push_fixture/.github/scripts/assert-macos-signing-workflows.sh"

quoted_dispatch_fixture="$(make_fixture quoted-dispatch)"
ruby - "$quoted_dispatch_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
abort "quoted-dispatch fixture anchor missing" unless text.sub!(
  "on:\n  workflow_dispatch:",
  "on:\n  \"workflow_dispatch\":"
)
File.binwrite(path, text)
RUBY
expect_failure quoted-workflow-dispatch \
  bash "$quoted_dispatch_fixture/.github/scripts/assert-macos-signing-workflows.sh"

flow_event_fixture="$(make_fixture flow-event)"
ruby - "$flow_event_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
start = text.index("on:\n") or abort "flow-event start anchor missing"
finish = text.index("\npermissions:", start) or abort "flow-event end anchor missing"
text[start...finish] = "on: [workflow_dispatch]\n"
File.binwrite(path, text)
RUBY
expect_failure flow-event-syntax \
  bash "$flow_event_fixture/.github/scripts/assert-macos-signing-workflows.sh"

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
replacement = anchor.sub("uses: actions/checkout@v6", "uses: attacker/source-spoofer@v1")
abort "checkout-action fixture anchor missing" unless job.sub!(anchor, replacement)
text[job_start...job_end] = job
File.binwrite(path, text)
RUBY
expect_failure unexpected-checkout-action \
  bash "$checkout_action_fixture/.github/scripts/assert-macos-signing-workflows.sh"

missing_checkout_path_fixture="$(make_fixture missing-checkout-path)"
ruby - "$missing_checkout_path_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
job_start = text.index("\n  package-mac:") or abort "package-mac fixture anchor missing"
job_end = text.index(/^  [[:alnum:]_-]+:/, job_start + "\n  package-mac:".length) || text.length
job = text[job_start...job_end]
abort "missing-path fixture anchor missing" unless job.sub!("          path: nonet\n", "")
text[job_start...job_end] = job
File.binwrite(path, text)
RUBY
expect_failure missing-checkout-path \
  bash "$missing_checkout_path_fixture/.github/scripts/assert-macos-signing-workflows.sh"

altered_checkout_path_fixture="$(make_fixture altered-checkout-path)"
ruby - "$altered_checkout_path_fixture/.github/workflows/release-desktop.yml" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
job_start = text.index("\n  package-mac:") or abort "package-mac fixture anchor missing"
job_end = text.index(/^  [[:alnum:]_-]+:/, job_start + "\n  package-mac:".length) || text.length
job = text[job_start...job_end]
abort "altered-path fixture anchor missing" unless job.sub!(
  "          path: nonet\n",
  "          path: attacker-source\n"
)
text[job_start...job_end] = job
File.binwrite(path, text)
RUBY
expect_failure altered-checkout-path \
  bash "$altered_checkout_path_fixture/.github/scripts/assert-macos-signing-workflows.sh"

comment_bypass_fixture="$(make_fixture comment-bypass)"
ruby - "$comment_bypass_fixture/.github/scripts/production-macos-signing.sh" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = <<'CODE'
  [[ "$actual_sha" == "$main_sha" ]] \
    || fail "checked-out source is not the authenticated origin/main commit"
CODE
replacement = <<'CODE'
  # [[ "$actual_sha" == "$main_sha" ]] \
  #   || fail "checked-out source is not the authenticated origin/main commit"
CODE
abort "comment-bypass fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure comment-only-exact-main \
  bash "$comment_bypass_fixture/.github/scripts/assert-macos-signing-workflows.sh"

altered_operator_fixture="$(make_fixture altered-operator)"
ruby - "$altered_operator_fixture/.github/scripts/production-macos-signing.sh" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = '  [[ "$actual_sha" == "$main_sha" ]] ' + "\\"
replacement = '  [[ "$actual_sha" != "$main_sha" ]] ' + "\\"
abort "altered-operator fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure altered-exact-main-operator \
  bash "$altered_operator_fixture/.github/scripts/assert-macos-signing-workflows.sh"

altered_variable_fixture="$(make_fixture altered-variable)"
ruby - "$altered_variable_fixture/.github/scripts/production-macos-signing.sh" <<'RUBY'
path = ARGV.fetch(0)
text = File.binread(path)
needle = '  [[ "$actual_sha" == "$main_sha" ]] ' + "\\"
replacement = '  [[ "$actual_sha" == "$REQUESTED_SOURCE_SHA" ]] ' + "\\"
abort "altered-variable fixture anchor missing" unless text.sub!(needle, replacement)
File.binwrite(path, text)
RUBY
expect_failure altered-exact-main-variable \
  bash "$altered_variable_fixture/.github/scripts/assert-macos-signing-workflows.sh"

echo 'assert-macos-signing-workflows.test: passed'
