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
SHA for the release workflow; do not use `main` for a production release
because it can move between jobs.

## 2. Run the dual-platform release workflow

From this repository:

```bash
SOURCE_SHA=<full-matrix-co-commit-sha>
gh workflow run release-desktop.yml \
  --repo moonaries90/matrix-co-releases \
  -f source_ref="$SOURCE_SHA"
```

The default tag is `desktop-YYYY.MM.DD`, and successful runs publish only after
the complete four-asset draft has been verified. To exercise the full build
without publishing, provide a unique test tag and keep the result as a draft:

```bash
gh workflow run release-desktop.yml \
  --repo moonaries90/matrix-co-releases \
  -f source_ref="$SOURCE_SHA" \
  -f release_tag="desktop-ci-test-$(date -u +%Y%m%d%H%M%S)" \
  -f publish_release=false
```

The workflow runs the native exports in parallel, then assembles one signed
catalog only after both artifacts exist. Both package jobs consume that exact
catalog. The catalog epoch comes from `release-epoch` at the selected source
commit. The catalog key is decoded only inside the assembly job from
`MATRIX_CO_RELEASE_PRIVATE_KEY_B64`; the private source is read through the
read-only `MATRIX_CO_SOURCE_DEPLOY_KEY`.

Find and watch the dispatched run:

```bash
gh run list --repo moonaries90/matrix-co-releases \
  --workflow release-desktop.yml --limit 3
gh run watch <run-id> --repo moonaries90/matrix-co-releases --exit-status
```

The run itself verifies:

- macOS DMG passes `hdiutil verify`.
- The mounted app passes `codesign --verify --deep --strict`.
- The main macOS executable reports `arm64`.
- Windows contains exactly one NSIS installer and a complete `portable/`
  directory.
- The Windows workflow verified the installer is currently `NotSigned`.
- Both package evidence documents match the same catalog JSON, signature,
  source commit, tree OID, and epoch.
- The draft contains exactly the four normalized assets, with remote byte sizes
  and SHA-256 digests equal to the locally prepared files.

## 3. Verify the published release

The publish job creates a draft first, uploads all four assets, verifies the
complete remote asset set, and only then clears the draft flag. A failed upload
therefore cannot become the latest public release.

Verify the release is public, not a draft or prerelease, and that the reported
asset sizes match the local files:

```bash
gh release view desktop-YYYY.MM.DD \
  --repo moonaries90/matrix-co-releases \
  --json url,isDraft,isPrerelease,targetCommitish,assets
```

Follow each public asset URL and require HTTP 200 before touching the website.

## 4. Update and deploy the website

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
