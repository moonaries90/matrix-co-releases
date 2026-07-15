# Matrix Co TUI 0.0.3

Apple Silicon macOS TUI build from Matrix Co source commit `5b9a7b374bc9f89e4e27e8425e0f3f4f62ded007`.

This update improves room history and message positioning, persists room reading position, removes terminal control codes from command output, compacts streamed command lifecycle output, and includes the latest permission and routing fixes.

## Requirements

- Apple Silicon Mac
- macOS 11 or later
- Homebrew
- Node.js 18 or later only when using the Claude SDK or experimental Cursor SDK transport

Third-party agent CLIs are not bundled. Install and authenticate the Codex, Claude Code, Cursor, Kimi, or ZCode CLI separately for the adapters you plan to use.

## Install or upgrade

```bash
brew tap moonaries90/matrix-co https://github.com/moonaries90/matrix-co-releases.git
brew update
brew upgrade matrix-co
```

For a first install, replace the last command with:

```bash
brew install moonaries90/matrix-co/matrix-co
```

## Verify

```bash
matrix --help
matrixctl agent --help
```

## Artifact

- File: `matrix-co-tui-0.0.3-darwin-arm64.tar.gz`
- Size: 23,584,011 bytes (about 23 MB)
- SHA-256: `6b206fb21e4224066e624e50e846b04563888e81499cb5c7df96cbe6755698ea`
