# Matrix Co Releases

This repository publishes verified Matrix Co Desktop and TUI release artifacts, plus the Homebrew formula for the macOS TUI distribution.

## Download the Desktop app

Download the latest Apple Silicon DMG from this repository's GitHub Releases. Desktop builds are currently ad-hoc signed but not Developer ID signed or notarized, so macOS may require right-clicking the app and choosing **Open** on first launch.

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

Publish `dist/matrix-co-desktop/Matrix Co.dmg` under a `desktop-YYYY.MM.DD` GitHub Release in this repository. Verify the DMG checksum and contents before updating the website download link.

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
