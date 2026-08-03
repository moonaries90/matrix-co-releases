# Nonet Releases

This repository is the public release channel for **Nonet Desktop**. The
application source repository is private, so the artifacts published under this
repository's GitHub Releases are the only unauthenticated download path.

## What is Nonet?

Nonet is a local-first group-chat workspace for multiple AI coding agents:
you create rooms on your own machine and spawn several agents — Claude Code,
Codex, Cursor, Kimi, ZCode — into the same conversation. The Desktop app is the
supported distribution and is fully self-contained: it bundles the Nonet
daemon, every agent adapter, and the SDK workers, so there is nothing else to
install from Nonet itself.

Highlights:

- **Multi-agent rooms** — chat with several coding agents in one room, with
  host-coordinated and free chat modes, plus goal-driven auto-run chains.
- **Approvals** — review and answer agent command/tool permission requests
  from a dedicated approvals surface.
- **Agent profiles and resume** — save reusable agent configurations and
  resume previous sessions.
- **Workspaces and files** — per-agent working directories, file attachments,
  and inline file preview in the transcript.
- **Remote connections** — attach to a remote machine over SSH.
- **In-app updates** — the app checks this repository's signed update feed
  (`latest.json` + `latest.json.sig`) and offers new releases.

Third-party agent CLIs (Codex, Claude Code, Cursor, Kimi, ZCode) are **not**
included; install and authenticate them separately. Node.js 18 or later is
needed only for the Claude SDK and experimental Cursor SDK transports.

## Download the Desktop app

Download the latest release from this repository's GitHub Releases page. Each
release ships:

| Asset | Purpose |
|---|---|
| `Nonet-macos-arm64.dmg` | macOS installer (Apple Silicon) |
| `Nonet-windows-x64-setup.exe` | Windows installer (NSIS) |
| `Nonet-windows-x64-portable.zip` | Windows portable package (no installer) |
| `SHA256SUMS.txt` | SHA-256 checksums for the packages above |
| `latest.json` / `latest.json.sig` | Signed update feed consumed by the app's in-app update check |

### First launch

Desktop builds do not currently use a public code-signing certificate:

- macOS builds are ad-hoc signed but not Developer ID signed or notarized, so
  macOS may require right-clicking the app and choosing **Open** on first launch.
- Windows builds are unsigned, so Microsoft Defender SmartScreen may show an
  unrecognized-app warning.

### Verify a download

```bash
# macOS
shasum -a 256 -c SHA256SUMS.txt --ignore-missing
```

```powershell
# Windows
certutil -hashfile Nonet-windows-x64-setup.exe SHA256
# compare against the matching line in SHA256SUMS.txt
```

## Homebrew TUI (retired)

Earlier versions of Nonet (under the previous `matrix-co` name) shipped a
terminal UI via Homebrew. That channel is retired: the release archives,
formula, and packaging script have all been removed, and no new TUI builds are
published here. The Desktop app above is the only supported distribution.
Historical TUI release notes remain under [`releases/`](releases/) as archive.

If you still have the old tap installed, clean it up with:

```bash
brew uninstall nonet 2>/dev/null || brew uninstall matrix-co 2>/dev/null
brew untap moonaries90/nonet
```

## Maintainer release flow

For the complete cross-platform Desktop procedure, including exact-SHA CI
builds, artifact verification, GitHub Release publication, and website updates,
see [`docs/desktop-release.md`](docs/desktop-release.md).

For a normal release, run the **Release dual-platform desktop** workflow once
with an immutable source commit. It exports both native runtime closures,
assembles one signed dual-platform catalog, packages macOS and Windows from that
same catalog, signs an update feed over the exact package bytes, creates a
draft, uploads and verifies all six public assets, and only then publishes the
release. Update the website only after the workflow has published and verified
the release.

```bash
gh workflow run release-desktop.yml \
  --repo moonaries90/nonet-releases \
  -f source_ref=<full-nonet-commit-sha>
```

The older platform-specific build workflows remain available for package
diagnostics; they are not the normal release path.

### Windows CI package

Run the **Build Windows desktop** workflow manually and provide a branch, tag,
or commit SHA from the private `moonaries90/nonet` repository. The workflow
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
