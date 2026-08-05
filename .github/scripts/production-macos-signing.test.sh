#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
verifier="$ROOT/.github/scripts/production-macos-signing.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/nonet-production-provenance.XXXXXXXX")"
cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

repo="$test_root/source"
git init -q -b main "$repo"
git -C "$repo" config user.name 'Nonet Provenance Test'
git -C "$repo" config user.email 'provenance-test@nonet.invalid'
printf 'main\n' > "$repo/payload.txt"
git -C "$repo" add payload.txt
git -C "$repo" commit -q -m main
main_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" switch -q -c review
printf 'review\n' >> "$repo/payload.txt"
git -C "$repo" commit -q -am review
review_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" remote add origin git@github.com:moonaries90/nonet.git
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

verify() {
  SOURCE_DIR="$repo" \
  REQUESTED_SOURCE_SHA="${1:-$review_sha}" \
  NONET_MACOS_SIGNING_APPROVED_SOURCE_SHA="${2:-$review_sha}" \
    bash "$verifier" verify-provenance
}

expect_failure() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "production-macos-signing.test: $label unexpectedly passed" >&2
    exit 1
  fi
  printf '%s=rejected\n' "$label"
}

GIT_SSH_COMMAND=/usr/bin/false verify >/dev/null
echo 'valid-offline-checkout=passed'
expect_failure requested-mismatch verify \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$review_sha"
expect_failure approved-mismatch verify \
  "$review_sha" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

git -C "$repo" update-ref -d refs/remotes/origin/main
expect_failure missing-local-main-ref verify
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

git -C "$repo" symbolic-ref HEAD refs/heads/missing-local-object
expect_failure missing-local-head-object verify
git -C "$repo" symbolic-ref HEAD refs/heads/review

git -C "$repo" remote set-url origin git@github.com:attacker/nonet.git
expect_failure spoofed-remote verify
git -C "$repo" remote set-url origin git@github.com:moonaries90/nonet.git

git -C "$repo" replace "$review_sha" "$main_sha"
expect_failure replacement-object-state verify
git -C "$repo" replace -d "$review_sha" >/dev/null

git -C "$repo" switch -q --orphan unrelated
printf 'unrelated\n' > "$repo/unrelated.txt"
git -C "$repo" add unrelated.txt
git -C "$repo" commit -q -m unrelated
unrelated_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" update-ref refs/remotes/origin/main "$unrelated_sha"
git -C "$repo" switch -q review
expect_failure insufficient-ancestry verify
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

printf 'dirty\n' >> "$repo/payload.txt"
expect_failure dirty-tracked-checkout verify
git -C "$repo" restore payload.txt

echo 'production-macos-signing.test: passed'
