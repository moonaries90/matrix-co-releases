#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "production-macos-signing: $*" >&2
  exit 1
}

verify_provenance() {
  : "${SOURCE_DIR:?SOURCE_DIR is required}"
  : "${REQUESTED_SOURCE_SHA:?REQUESTED_SOURCE_SHA is required}"
  [[ "$REQUESTED_SOURCE_SHA" =~ ^[[:xdigit:]]{40}$ ]] \
    || fail "source_ref must be a full 40-hex commit SHA"
  [[ -z "${GIT_OBJECT_DIRECTORY:-}" \
    && -z "${GIT_ALTERNATE_OBJECT_DIRECTORIES:-}" \
    && -z "${GIT_REPLACE_REF_BASE:-}" ]] \
    || fail "Git object or replacement overrides are forbidden"

  local expected_remote actual_remote main_ref actual_sha main_sha git_path
  expected_remote='git@github.com:moonaries90/nonet.git'
  actual_remote="$(git -C "$SOURCE_DIR" config --local --get remote.origin.url)" \
    || fail "source checkout has no origin URL"
  [[ "$actual_remote" == "$expected_remote" ]] \
    || fail "source checkout origin is not moonaries90/nonet"
  [[ "$(git -C "$SOURCE_DIR" config --local --get-all remote.origin.url | wc -l | tr -d ' ')" == "1" ]] \
    || fail "source checkout has ambiguous origin URLs"

  git_path="$(git -C "$SOURCE_DIR" rev-parse --git-path info/grafts)"
  [[ "$git_path" == /* ]] || git_path="$SOURCE_DIR/$git_path"
  [[ ! -s "$git_path" ]] || fail "Git grafts are forbidden"
  git_path="$(git -C "$SOURCE_DIR" rev-parse --git-path objects/info/alternates)"
  [[ "$git_path" == /* ]] || git_path="$SOURCE_DIR/$git_path"
  [[ ! -s "$git_path" ]] || fail "Git object alternates are forbidden"
  [[ -z "$(git -C "$SOURCE_DIR" for-each-ref --format='%(refname)' refs/replace)" ]] \
    || fail "Git replacement refs are forbidden"
  git -C "$SOURCE_DIR" diff --quiet --ignore-submodules -- \
    || fail "source checkout has tracked worktree changes"
  git -C "$SOURCE_DIR" diff --cached --quiet --ignore-submodules -- \
    || fail "source checkout has staged changes"

  actual_sha="$(git -C "$SOURCE_DIR" rev-parse --verify 'HEAD^{commit}')"
  git -C "$SOURCE_DIR" cat-file -e "${actual_sha}^{commit}" \
    || fail "checked-out commit object is missing"
  [[ "$actual_sha" == "$REQUESTED_SOURCE_SHA" ]] \
    || fail "checked-out source does not match source_ref"
  main_ref='refs/remotes/origin/main'
  main_sha="$(git -C "$SOURCE_DIR" rev-parse --verify "${main_ref}^{commit}")" \
    || fail "authenticated checkout did not fetch origin/main"
  git -C "$SOURCE_DIR" cat-file -e "${main_sha}^{commit}" \
    || fail "origin/main commit object is missing"
  [[ "$actual_sha" == "$main_sha" ]] \
    || fail "checked-out source is not the authenticated origin/main commit"
  printf 'source_sha=%s\n' "$actual_sha"
  printf 'source_main_sha=%s\n' "$main_sha"
  printf 'source_remote=%s\n' 'github.com/moonaries90/nonet'
}

setup() {
  verify_provenance
  : "${RUNNER_TEMP:?RUNNER_TEMP is required}"
  : "${GITHUB_ENV:?GITHUB_ENV is required}"
  : "${NONET_MACOS_SIGNING_P12_B64:?NONET_MACOS_SIGNING_P12_B64 is required}"
  : "${NONET_MACOS_SIGNING_P12_PASSWORD:?NONET_MACOS_SIGNING_P12_PASSWORD is required}"
  : "${NONET_MACOS_SIGNING_CERT_SHA256:?NONET_MACOS_SIGNING_CERT_SHA256 is required}"

  umask 077
  local secret_dir="$RUNNER_TEMP/nonet-signing-input"
  [[ ! -e "$secret_dir" && ! -L "$secret_dir" ]] \
    || fail "signing input path already exists"
  mkdir -m 0700 "$secret_dir"
  local p12_file="$secret_dir/identity.p12"
  local password_file="$secret_dir/password.txt"
  cleanup_inputs() {
    rm -f -- "$p12_file" "$password_file"
    rmdir "$secret_dir" >/dev/null 2>&1 || true
  }
  trap cleanup_inputs EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  printf '%s' "$NONET_MACOS_SIGNING_P12_B64" | base64 --decode > "$p12_file" \
    || fail "NONET_MACOS_SIGNING_P12_B64 is not valid base64"
  printf '%s' "$NONET_MACOS_SIGNING_P12_PASSWORD" > "$password_file"
  chmod 0600 "$p12_file" "$password_file"
  unset NONET_MACOS_SIGNING_P12_B64 NONET_MACOS_SIGNING_P12_PASSWORD

  local env_file
  env_file="$(RUNNER_TEMP="$RUNNER_TEMP" \
    NONET_MACOS_SIGNING_P12_FILE="$p12_file" \
    NONET_MACOS_SIGNING_PASSWORD_FILE="$password_file" \
    NONET_MACOS_SIGNING_CERT_SHA256="$NONET_MACOS_SIGNING_CERT_SHA256" \
    bash "$SOURCE_DIR/scripts/macos-signing-keychain.sh" setup)"
  cat "$env_file" >> "$GITHUB_ENV"
  cleanup_inputs
  trap - EXIT INT TERM
  # Values below are fingerprints and paths, never private material.
  # shellcheck disable=SC1090
  source "$env_file"
  printf 'certificate_sha256=%s\n' "$NONET_MACOS_SIGNING_CERT_SHA256"
  printf 'certificate_sha1=%s\n' "$NONET_MACOS_SIGNING_CERT_SHA1"
}

cleanup() {
  : "${SOURCE_DIR:?SOURCE_DIR is required}"
  : "${RUNNER_TEMP:?RUNNER_TEMP is required}"
  if [[ -n "${NONET_MACOS_SIGNING_STATE_DIR:-}" ]]; then
    RUNNER_TEMP="$RUNNER_TEMP" \
      bash "$SOURCE_DIR/scripts/macos-signing-keychain.sh" cleanup \
        "$NONET_MACOS_SIGNING_STATE_DIR"
  fi
  rm -f -- "$RUNNER_TEMP/nonet-signing-input/identity.p12" \
    "$RUNNER_TEMP/nonet-signing-input/password.txt"
  rmdir "$RUNNER_TEMP/nonet-signing-input" >/dev/null 2>&1 || true
}

case "${1:-}" in
  verify-provenance) verify_provenance ;;
  setup) setup ;;
  cleanup) cleanup ;;
  *) fail "usage: $0 <verify-provenance|setup|cleanup>" ;;
esac
