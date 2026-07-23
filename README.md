# Matrix Co Releases

This repository publishes verified Matrix Co Desktop and TUI release artifacts, plus the Homebrew formula for the macOS TUI distribution.

## Download the Desktop app

Download the latest Apple Silicon macOS DMG or Windows x64 installer from this
repository's GitHub Releases.

Desktop builds do not currently use a public code-signing certificate:

- macOS builds are ad-hoc signed but not Developer ID signed or notarized, so
  macOS may require right-clicking the app and choosing **Open** on first launch.
- Windows builds are unsigned, so Microsoft Defender SmartScreen may show an
  unrecognized-app warning.

## Install the TUI with Homebrew

Matrix Co TUI currently supports Apple Silicon Macs running macOS 11 or later.

```bash
brew tap moonaries90/matrix-co https://github.com/moonaries90/matrix-co-releases.git
brew install moonaries90/matrix-co/matrix-co
```

Or run both steps in one command:

```bash
brew tap moonaries90/matrix-co https://github.com/moonaries90/matrix-co-releases.git && brew install moonaries90/matrix-co/matrix-co
```

Then verify the installation:

```bash
matrix --help
matrixctl agent --help
```

The package includes the Matrix Co launcher, daemon, TUI, control CLI, adapters, and the Node workers used by supported SDK transports. Node.js 18 or later is needed only for the Claude SDK and experimental Cursor SDK transports. Third-party agent CLIs such as Codex, Claude Code, Cursor, Kimi, and ZCode are not included and must be installed and authenticated separately.

## Upgrade or uninstall

```bash
brew update
brew upgrade matrix-co
```

```bash
brew uninstall matrix-co
brew untap moonaries90/matrix-co
```

## Maintainer release flow

Build the TUI from this repository:

```bash
scripts/package-tui-release.sh 0.0.2
```

The script rebuilds the package from the sibling `matrix-co` source checkout by default, validates the required runtime files and architecture, and writes a versioned archive plus `SHA256SUMS` under `dist/tui-v<version>/`.

Commit and push the release files, then publish the generated archive and `SHA256SUMS` under the matching `tui-v<version>` GitHub Release. Verify the public Formula URL, checksum, and installed command smoke before announcing the release.

Build the Desktop app from the sibling `matrix-co` source checkout:

```bash
cd ../matrix-co
bash scripts/package-desktop.sh
```

For normal releases, run both Desktop CI workflows with the same source commit,
verify their artifacts, and publish the macOS DMG, Windows installer, Windows
portable archive, and combined checksums under a `desktop-YYYY.MM.DD` GitHub
Release. Update the website only after all published assets are verified.

### Windows CI package

Run the **Build Windows desktop** workflow manually and provide a branch, tag,
or commit SHA from the private `moonaries90/matrix-co` repository. The workflow
builds the existing `scripts/package-desktop.ps1` pipeline on a pinned
`windows-2022` runner and uploads the unsigned NSIS installer and portable
package as a 14-day Actions artifact.

The workflow reads the private source repository through the dedicated,
read-only deploy key stored in the `MATRIX_CO_SOURCE_DEPLOY_KEY` Actions secret.
It intentionally does not publish a GitHub Release until the downloaded
artifact has been verified.

### macOS CI package

Run the **Build macOS desktop** workflow with the same source commit used for
Windows. It packages the existing `scripts/package-desktop.sh` pipeline on an
Apple Silicon runner, verifies the app's ad-hoc signature and architecture,
validates the DMG, and uploads the DMG plus its SHA-256 checksum as a 14-day
Actions artifact.
