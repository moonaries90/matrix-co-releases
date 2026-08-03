# Nonet Releases Agent Guide

This repository owns Nonet Desktop release automation, published artifacts,
and release notes. The private application source repository is a build input
and must be treated as read-only here.

The Homebrew TUI channel is retired (2026-08-03): the formula and TUI
packaging script have been removed, and no new TUI archives are published. The
TUI is built from source locally by the maintainer for personal headless use.
Historical TUI release notes remain under `releases/` as archive only.

## Scope routing

| Change area | Read first | Verification |
|---|---|---|
| Desktop release | `docs/desktop-release.md`, both files in `.github/workflows/` | Build macOS and Windows from the same immutable source SHA; verify every published asset and checksum |
| Desktop CI workflow | Relevant workflow and the packaging script under `/Users/lji/projects/github/nonet/scripts/` | Run the changed workflow manually with an exact source SHA |
| Release notes | Most recent matching file under `releases/` | Confirm version, source SHA, architecture, byte size, checksum, and signing disclosure |
| Website download links | `/Users/lji/projects/k8s/matrix-site/AGENTS.md`, `docs/desktop-release.md` | Update only after the GitHub Release is public and its assets return HTTP 200 |

## Release invariants

- Use one immutable `nonet` commit SHA for every platform in a Desktop
  release. Never mix branch heads or artifacts from different source commits.
- Normal Desktop releases are built by GitHub Actions. A maintainer does not
  need to package on a local Mac or Windows machine unless CI itself is being
  diagnosed.
- The private source checkout uses the read-only
  `MATRIX_CO_SOURCE_DEPLOY_KEY` repository secret. Never print, copy, or persist
  the private key.
- Publish and verify the GitHub Release before changing the website download
  links.
- Do not claim Developer ID signing, notarization, or Windows code signing
  unless the workflow and the published artifact independently verify it.
- Keep release files under `releases/`; keep reusable procedure in `docs/`.
  Do not turn this routing file into a release log.

## Repository boundaries

- Do not modify `/Users/lji/projects/github/nonet` from this repository.
- Do not place downloaded build artifacts in Git. Use a temporary directory.
- Do not overwrite or delete an existing public release without explicit user
  approval. Correct a bad release with a new tag unless directed otherwise.
