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
  local actual_sha
  actual_sha="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
  [[ "$actual_sha" == "$REQUESTED_SOURCE_SHA" ]] \
    || fail "checked-out source does not match source_ref"
  git -C "$SOURCE_DIR" fetch --no-tags origin main
  if ! git -C "$SOURCE_DIR" merge-base --is-ancestor \
    "$actual_sha" origin/main; then
    [[ -n "${NONET_MACOS_SIGNING_APPROVED_SOURCE_SHA:-}" \
      && "$actual_sha" == "$NONET_MACOS_SIGNING_APPROVED_SOURCE_SHA" ]] \
      || fail "source commit is neither on origin/main nor the protected review pin"
  fi
  printf 'source_sha=%s\n' "$actual_sha"
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
  trap cleanup_inputs EXIT ERR INT TERM
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
  trap - EXIT ERR INT TERM
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
