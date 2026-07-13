# Matrix Co TUI 0.0.1

First public Apple Silicon release of the Matrix Co terminal interface.

## Requirements

- Apple Silicon Mac
- macOS 11 or later
- Homebrew
- Node.js 18 or later only when using the Claude SDK or experimental Cursor SDK transport

Third-party agent CLIs are not bundled. Install and authenticate the Codex, Claude Code, Cursor, Kimi, or ZCode CLI separately for the adapters you plan to use.

## Install

```bash
brew tap moonaries90/matrix-co https://github.com/moonaries90/matrix-co-releases.git
brew install moonaries90/matrix-co/matrix-co
```

## Verify

```bash
matrix --help
matrixctl agent --help
```

## Artifact

- File: `matrix-co-tui-0.0.1-darwin-arm64.tar.gz`
- Size: approximately 23 MB
- SHA-256: `7ba614efda348c3c21c49f8ffff999d7f9b74d778c755b356e98ba8273f9cad9`
- Matrix Co source commit: `1078c116c8f30026682d5e8f78d24a508d77ab85`
