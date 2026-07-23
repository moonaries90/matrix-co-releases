# Desktop Release Runbook

Use this runbook to publish one Matrix Co Desktop release for Apple Silicon
macOS and x64 Windows, then update the product website.

## 1. Select one source commit

The source repository is private and is read-only during this process.

```bash
git -C /Users/lji/projects/github/matrix-co fetch origin
git -C /Users/lji/projects/github/matrix-co status --short --branch
git -C /Users/lji/projects/github/matrix-co rev-parse HEAD
git -C /Users/lji/projects/github/matrix-co rev-parse origin/main
```

Proceed only when the intended source tree is clean and the selected commit is
already available on GitHub. Record the full 40-character SHA. Use that exact
SHA for both workflows; do not use `main` for a production release because it
can move between builds.

## 2. Build both platforms in GitHub Actions

From this repository:

```bash
SOURCE_SHA=<full-matrix-co-commit-sha>
gh workflow run build-macos.yml \
  --repo moonaries90/matrix-co-releases \
  -f source_ref="$SOURCE_SHA"
gh workflow run build-windows.yml \
  --repo moonaries90/matrix-co-releases \
  -f source_ref="$SOURCE_SHA"
```

The macOS workflow runs on Apple Silicon `macos-15`; the Windows workflow runs
on `windows-2022`. Both read the private source through the dedicated
read-only `MATRIX_CO_SOURCE_DEPLOY_KEY` secret.

Find and watch the two dispatched runs:

```bash
gh run list --repo moonaries90/matrix-co-releases \
  --workflow build-macos.yml --limit 3
gh run list --repo moonaries90/matrix-co-releases \
  --workflow build-windows.yml --limit 3
gh run watch <run-id> --repo moonaries90/matrix-co-releases --exit-status
```

Both runs must succeed. Their logs must show the same source SHA.

## 3. Download and verify artifacts

Create a temporary directory and download each successful run:

```bash
RELEASE_TMP=$(mktemp -d)
gh run download <macos-run-id> \
  --repo moonaries90/matrix-co-releases \
  --dir "$RELEASE_TMP/macos"
gh run download <windows-run-id> \
  --repo moonaries90/matrix-co-releases \
  --dir "$RELEASE_TMP/windows"
```

Verify at minimum:

- macOS DMG passes `hdiutil verify`.
- The mounted app passes `codesign --verify --deep --strict`.
- The main macOS executable reports `arm64`.
- Windows contains exactly one NSIS installer and a complete `portable/`
  directory.
- Published installer hashes match the downloaded workflow checksums.
- The Windows workflow verified the installer is currently `NotSigned`.

Normalize public asset names:

- `Matrix.Co-macos-arm64.dmg`
- `Matrix.Co-windows-x64-setup.exe`
- `Matrix.Co-windows-x64-portable.zip`
- `SHA256SUMS.txt`

Compute a fresh combined SHA-256 list after renaming and packaging. Record
exact byte sizes and checksums in the release notes.

## 4. Publish the GitHub Release

Use `desktop-YYYY.MM.DD` for the tag and
`Matrix Co Desktop YYYY.MM.DD` for the title. Add
`releases/desktop-YYYY.MM.DD.md` before publishing.

Release notes must include:

- the full source commit SHA;
- supported OS and architecture;
- exact filenames, byte sizes, and SHA-256 hashes;
- installation instructions;
- current signing and notarization status;
- the fact that third-party provider CLIs are not bundled.

Commit and push the runbook/release-note changes before creating the release.
Then publish all four assets with `gh release create`.

Verify the release is public, not a draft or prerelease, and that the reported
asset sizes match the local files:

```bash
gh release view desktop-YYYY.MM.DD \
  --repo moonaries90/matrix-co-releases \
  --json url,isDraft,isPrerelease,targetCommitish,assets
```

Follow each public asset URL and require HTTP 200 before touching the website.

## 5. Update and deploy the website

In `/Users/lji/projects/k8s/matrix-site`, update the two Desktop cards in
`index.html` with the new tag, exact public filenames, approximate sizes, and
signing warnings. Keep macOS and Windows on the same release version.

Run:

```bash
node --check main.js
sh scripts/build.sh
npm run deploy
curl -I https://matrix-co.pages.dev/
```

Inspect the download section at desktop and mobile widths. Verify the production
HTML contains both new release URLs and that each download resolves publicly.

## Signing boundary

The current expected state is:

- macOS: ad-hoc signed, not Developer ID signed, not notarized.
- Windows: unsigned; SmartScreen may warn.

This is sufficient for packaging and publication but not for a warning-free
installation experience. Introducing Developer ID/notarization or Windows code
signing is a separate security-sensitive change and must update both workflows,
verification, release notes, and website disclosures together.
