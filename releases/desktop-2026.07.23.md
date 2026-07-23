# Matrix Co Desktop 2026.07.23

macOS and Windows desktop builds from Matrix Co source commit
`ec8e4bf82a532492e2181c8a0dbe163a28036e06`.

This release adds the native Windows desktop package alongside the Apple
Silicon macOS build. It also refreshes the default green visual theme and app
icon, improves room routing and agent management, supports attachment and final
file delivery, and strengthens daemon restart, session recovery, packaging, and
provider integration behavior.

## Install

### macOS

1. Download `Matrix.Co-macos-arm64.dmg`.
2. Open the DMG and copy Matrix Co to Applications.
3. This build is ad-hoc signed but not Developer ID signed or notarized. On
   first launch, right-click Matrix Co and choose **Open** if macOS blocks it.

### Windows

1. Download and run `Matrix.Co-windows-x64-setup.exe`.
2. This build is unsigned. Microsoft Defender SmartScreen may show an
   unrecognized-app warning; choose **More info** and **Run anyway** only after
   confirming the checksum.
3. `Matrix.Co-windows-x64-portable.zip` is available for users who prefer a
   portable package.

Third-party agent CLIs are not bundled. Install and authenticate the Codex,
Claude Code, Cursor, Kimi, or ZCode CLI separately for the adapters you plan to
use.

## Artifacts

- `Matrix.Co-macos-arm64.dmg`
  - Architecture: Apple Silicon (`arm64`)
  - Size: 40,603,790 bytes (about 39 MB)
  - SHA-256: `c1d591be972cdf493444ee66e0a5ae1e0d6b7daf7e8ac61dacce64139b768570`
- `Matrix.Co-windows-x64-setup.exe`
  - Architecture: Windows x64
  - Size: 13,896,564 bytes (about 13 MB)
  - SHA-256: `0445e1c070ec6b07d16f19794b123b3d26e00cad1821da0c734e3629079d3edc`
- `Matrix.Co-windows-x64-portable.zip`
  - Architecture: Windows x64
  - Size: 48,907,600 bytes (about 47 MB)
  - SHA-256: `3cce2aaf7bd84db1e49dc83a4230d2e268f31d285e2459028e9e5126f4cb4205`

See `SHA256SUMS.txt` for the combined checksum list.
