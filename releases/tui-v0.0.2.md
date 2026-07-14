# Matrix Co TUI 0.0.2

Apple Silicon macOS TUI build from Matrix Co source commit `8ae87a232275657ef77f3de104be25ed09fe3f99`.

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

- File: `matrix-co-tui-0.0.2-darwin-arm64.tar.gz`
- Size: 23,558,773 bytes (about 23 MB)
- SHA-256: `66bbfc3eabd6535c1aef6a4f9444603722a96b79d90d8963f09a59628384ebac`
