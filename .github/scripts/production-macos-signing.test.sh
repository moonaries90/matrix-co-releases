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
printf 'old main\n' > "$repo/payload.txt"
git -C "$repo" add payload.txt
git -C "$repo" commit -q -m old-main
old_main_sha="$(git -C "$repo" rev-parse HEAD)"
printf 'current main\n' > "$repo/payload.txt"
git -C "$repo" commit -q -am current-main
main_sha="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" remote add origin git@github.com:moonaries90/nonet.git
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

verify() {
  SOURCE_DIR="$repo" \
  REQUESTED_SOURCE_SHA="${1:-$(git -C "$repo" rev-parse HEAD)}" \
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

GIT_SSH_COMMAND=/usr/bin/false verify "$main_sha" >/dev/null
echo 'valid-exact-main-offline-checkout=passed'
expect_failure requested-mismatch verify \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

git -C "$repo" switch -q --detach "$old_main_sha"
expect_failure old-main-sha verify "$old_main_sha"
git -C "$repo" switch -q main

git -C "$repo" switch -q -c feature
printf 'feature\n' >> "$repo/payload.txt"
git -C "$repo" commit -q -am feature
feature_sha="$(git -C "$repo" rev-parse HEAD)"
expect_failure feature-branch-sha verify "$feature_sha"
git -C "$repo" switch -q main

git -C "$repo" switch -q --orphan unadvertised
printf 'unadvertised\n' > "$repo/unadvertised.txt"
git -C "$repo" add unadvertised.txt
git -C "$repo" commit -q -m unadvertised
unadvertised_sha="$(git -C "$repo" rev-parse HEAD)"
expect_failure unadvertised-object verify "$unadvertised_sha"
git -C "$repo" switch -q main

git -C "$repo" update-ref -d refs/remotes/origin/main
expect_failure missing-local-main-ref verify "$main_sha"
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

main_ref_path="$(git -C "$repo" rev-parse --git-path refs/remotes/origin/main)"
[[ "$main_ref_path" == /* ]] || main_ref_path="$repo/$main_ref_path"
rm -f -- "$main_ref_path"
mkdir -p "$(dirname "$main_ref_path")"
printf '%040d\n' 0 > "$main_ref_path"
expect_failure missing-main-object verify "$main_sha"
rm -f -- "$main_ref_path"
git -C "$repo" update-ref refs/remotes/origin/main "$main_sha"

git -C "$repo" symbolic-ref HEAD refs/heads/missing-local-object
expect_failure missing-local-head-object verify "$main_sha"
git -C "$repo" symbolic-ref HEAD refs/heads/main

git -C "$repo" remote set-url origin git@github.com:attacker/nonet.git
expect_failure spoofed-remote verify "$main_sha"
git -C "$repo" remote set-url origin git@github.com:moonaries90/nonet.git

git -C "$repo" config --add remote.origin.url git@github.com:attacker/nonet.git
expect_failure ambiguous-origin verify "$main_sha"
git -C "$repo" config --unset-all remote.origin.url
git -C "$repo" config remote.origin.url git@github.com:moonaries90/nonet.git

git -C "$repo" replace "$main_sha" "$old_main_sha"
expect_failure replacement-object-state verify "$main_sha"
git -C "$repo" replace -d "$main_sha" >/dev/null

grafts="$(git -C "$repo" rev-parse --git-path info/grafts)"
[[ "$grafts" == /* ]] || grafts="$repo/$grafts"
mkdir -p "$(dirname "$grafts")"
printf '%s %s\n' "$main_sha" "$old_main_sha" > "$grafts"
expect_failure graft-state verify "$main_sha"
rm -f -- "$grafts"

alternates="$(git -C "$repo" rev-parse --git-path objects/info/alternates)"
[[ "$alternates" == /* ]] || alternates="$repo/$alternates"
mkdir -p "$(dirname "$alternates")"
printf '%s\n' "$test_root/forbidden-alternate" > "$alternates"
expect_failure alternate-state verify "$main_sha"
rm -f -- "$alternates"

expect_failure object-directory-override env \
  GIT_OBJECT_DIRECTORY="$test_root/objects" SOURCE_DIR="$repo" \
  REQUESTED_SOURCE_SHA="$main_sha" bash "$verifier" verify-provenance
expect_failure alternate-directory-override env \
  GIT_ALTERNATE_OBJECT_DIRECTORIES="$test_root/objects" SOURCE_DIR="$repo" \
  REQUESTED_SOURCE_SHA="$main_sha" bash "$verifier" verify-provenance
expect_failure replace-ref-base-override env \
  GIT_REPLACE_REF_BASE=refs/forbidden SOURCE_DIR="$repo" \
  REQUESTED_SOURCE_SHA="$main_sha" bash "$verifier" verify-provenance

printf 'dirty\n' >> "$repo/payload.txt"
expect_failure dirty-tracked-checkout verify "$main_sha"
git -C "$repo" restore payload.txt

printf 'staged\n' >> "$repo/payload.txt"
git -C "$repo" add payload.txt
expect_failure dirty-staged-checkout verify "$main_sha"
git -C "$repo" restore --staged --worktree payload.txt

echo 'production-macos-signing.test: passed'
