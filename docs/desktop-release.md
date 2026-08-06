# Desktop Release Runbook

Use this runbook to publish one Nonet Desktop release for Apple Silicon
macOS and x64 Windows, then update the product website.

## 1. Select one source commit

The source repository is private and is read-only during this process.

The production source is always the exact commit currently advertised as
`moonaries90/nonet` `main`. The canonical trigger resolves that full
40-character SHA through the authenticated GitHub API and passes the immutable
value to the workflow. It never passes a branch name.

## 2. Run the dual-platform release workflow

From a current `moonaries90/nonet` checkout:

```bash
scripts/trigger-github-actions.sh
```

The explicit script invocation is the signing authorization. The protected job
does not use a second deployment approval or a manually maintained source-SHA
pin. It fails closed unless the requested full SHA, checked-out `HEAD`, and the
authenticated local `refs/remotes/origin/main` fetched by the deploy-key
checkout are identical. Signing setup performs no network fetch. The
`production-signing` Environment remains attached to the job and permits only
the `nonet-releases` `main` workflow ref.

Residual risk: neither repository currently protects its `main` branch. A
collaborator able to move either main can change the source or workflow that a
later explicit trigger runs. Today `moonaries90` is the only direct
collaborator; manual dispatch is the intended authorization boundary.

The default tag is `desktop-YYYY.MM.DD`, and successful runs publish only after
the complete six-asset draft has been verified. To exercise the full build
without publishing, provide a unique test tag and disable publication:

```bash
scripts/trigger-github-actions.sh \
  --release-tag "desktop-ci-test-$(date -u +%Y%m%d%H%M%S)" \
  --draft
```

When `publish_release=false`, the workflow does not create even a draft GitHub
Release; build evidence remains in Actions artifacts only.

The workflow runs the native exports in parallel, then assembles one signed
catalog only after both artifacts exist. Both package jobs consume that exact
catalog. After both desktop packages exist, a dedicated `sign-feed` job
normalizes the three downloadable packages and signs a feed that binds their
exact SHA-256 digests and byte sizes. The catalog epoch comes from
`release-epoch` at the selected source commit. The catalog key is decoded only
inside the assembly and feed-signing jobs from
`MATRIX_CO_RELEASE_PRIVATE_KEY_B64`; both jobs use restrictive permissions,
remove the decoded key on exit, and unset the secret after decoding. The
private source is read through the read-only `MATRIX_CO_SOURCE_DEPLOY_KEY`.

Find and watch the dispatched run:

```bash
gh run list --repo moonaries90/nonet-releases \
  --workflow release-desktop.yml --limit 3
gh run watch <run-id> --repo moonaries90/nonet-releases --exit-status
```

The run itself verifies:

- macOS DMG passes `hdiutil verify`.
- The mounted app passes `codesign --verify --deep --strict`.
- The copied and DMG-mounted macOS apps have identifier `co.nonet.desktop`,
  hardened-runtime/non-ad-hoc flags, the reviewed SHA-1 leaf and SHA-256
  certificate pin, identical normalized designated requirements, and valid
  deep/strict signatures.
- Every nested Mach-O executable, bridge, agent, support binary, framework, and
  dylib present in the app is explicitly signed with the intended leaf before
  the outer app is signed.
- The main macOS executable reports `arm64`.
- Windows contains exactly one NSIS installer and a complete `portable/`
  directory.
- The Windows workflow verified the installer is currently `NotSigned`.
- Both package evidence documents match the same catalog JSON, signature,
  source commit, tree OID, and epoch.
- The signed feed contains SHA-256 digests and byte sizes equal to the exact
  normalized packages passed to the publish job.
- The draft contains exactly six normalized assets: three desktop packages,
  `SHA256SUMS.txt`, `latest.json`, and `latest.json.sig`. Remote byte sizes and
  SHA-256 digests must equal the locally prepared files.

## 3. Verify the published release

The publish job creates a draft first, uploads all six assets, verifies the
complete remote asset set, and only then clears the draft flag. A failed upload
therefore cannot become the latest public release.

Verify the release is public, not a draft or prerelease, and that the reported
asset sizes match the local files:

```bash
gh release view desktop-YYYY.MM.DD \
  --repo moonaries90/nonet-releases \
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

- macOS: signed with one stable Nonet self-signed identity, not Developer ID
  signed, and not notarized. The P12 and its password are Environment secrets
  `NONET_MACOS_SIGNING_P12_B64` and
  `NONET_MACOS_SIGNING_P12_PASSWORD`. Only the protected production packaging
  job imports them into an ephemeral keychain. The reviewed public SHA-256 pin
  is checked into the workflow; the SHA-1 leaf is recorded alongside it for
  SecRequirement evidence. The general macOS build workflow is deliberately
  ad-hoc and non-publishable.
- Windows: unsigned; SmartScreen may warn.

The first release that switches from ad-hoc signing requires users to grant
their macOS privacy permissions one final time. Later builds signed with the
same identity retain the same designated requirement. This is sufficient for
stable TCC identity, but not for a warning-free installation experience.
Introducing Developer ID/notarization or Windows code signing is a separate
security-sensitive change and must update workflows, verification, release
notes, and website disclosures together.
