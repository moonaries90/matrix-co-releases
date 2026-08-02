#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION="${1:-0.0.1}"
SOURCE_ROOT="${NONET_CO_SOURCE_ROOT:-"$(cd "$ROOT/../nonet" && pwd -P)"}"
OUT_DIR="${2:-"$ROOT/dist/tui-v$VERSION"}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "invalid version: $VERSION" >&2
  exit 2
fi

case "$(uname -m)" in
  arm64) ARCH="arm64" ;;
  x86_64) ARCH="x86_64" ;;
  *)
    echo "unsupported macOS architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "TUI release packaging must run on macOS" >&2
  exit 2
fi

PACKAGE_DIR="$OUT_DIR/nonet"
ASSET_NAME="nonet-tui-$VERSION-darwin-$ARCH.tar.gz"
ASSET_PATH="$OUT_DIR/$ASSET_NAME"

if [[ ! -x "$SOURCE_ROOT/scripts/package-local.sh" ]]; then
  echo "missing Nonet package entrypoint: $SOURCE_ROOT/scripts/package-local.sh" >&2
  exit 1
fi

echo "==> rebuilding Nonet TUI package from $SOURCE_ROOT"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
(
  cd "$SOURCE_ROOT"
  scripts/package-local.sh "$PACKAGE_DIR"
)

required_files=(
  README.md
  bin/nonet
  bin/nonetctl
  bin/nonetd
  bin/nonet-tui
  bin/nonet-mcp
  bin/codex-agent
  bin/claude-agent
  bin/cursor-agent
  bin/cursor-sdk-agent
  bin/kimi-agent
  bin/zcode-agent
  lib/claude-sdk-agent/package.json
  lib/cursor-sdk-agent/package.json
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -e "$PACKAGE_DIR/$relative_path" ]]; then
    echo "release package is missing $relative_path" >&2
    exit 1
  fi
done

for binary in "$PACKAGE_DIR"/bin/*; do
  if file "$binary" | grep -q 'Mach-O'; then
    if ! file "$binary" | grep -q "$ARCH"; then
      echo "architecture mismatch: $binary is not $ARCH" >&2
      exit 1
    fi
  fi
done

# The source-local package intentionally mirrors the development checkout and
# copies complete node_modules trees. A public release only needs production
# runtime dependencies. The Claude adapter resolves and launches the user's
# installed `claude`, so omit the SDK's optional platform CLI packages just as
# the Desktop packager does. The experimental Cursor worker has no production
# npm dependencies and only needs its compiled dist output.
CLAUDE_WORKER="$PACKAGE_DIR/lib/claude-sdk-agent"
CURSOR_WORKER="$PACKAGE_DIR/lib/cursor-sdk-agent"
echo "==> pruning SDK workers for distribution"
rm -rf "$CLAUDE_WORKER/node_modules"
(
  cd "$CLAUDE_WORKER"
  npm ci --omit=dev --omit=optional --ignore-scripts
)
rm -rf "$CURSOR_WORKER/node_modules"

node --input-type=module -e \
  "import('$CLAUDE_WORKER/node_modules/@anthropic-ai/claude-agent-sdk/sdk.mjs')" \
  >/dev/null

git -C "$SOURCE_ROOT" rev-parse HEAD >"$PACKAGE_DIR/SOURCE_COMMIT"
printf '%s\n' "$VERSION" >"$PACKAGE_DIR/VERSION"
rm -rf "$PACKAGE_DIR/logs"

echo "==> creating $ASSET_NAME"
COPYFILE_DISABLE=1 tar -czf "$ASSET_PATH" -C "$OUT_DIR" nonet
(
  cd "$OUT_DIR"
  shasum -a 256 "$ASSET_NAME" >SHA256SUMS
)

echo "==> validating archive"
tar -tzf "$ASSET_PATH" >/dev/null
(
  cd "$OUT_DIR"
  shasum -a 256 -c SHA256SUMS
)

echo
echo "Release package ready:"
echo "  $ASSET_PATH"
echo "  $OUT_DIR/SHA256SUMS"
