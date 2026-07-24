# Matrix Co Desktop 2026.07.24

macOS and Windows desktop builds from Matrix Co source commit
`36b91ab046abcdb38e904294b325721d6c2e157a`.

This release improves Windows build and storage portability, preserves room
draft attachments across navigation, wires the desktop transcript and storage
controls to their settings, and refines agent and routing behavior. It also
adds Kimi K3 maximum effort support, lays the verified foundation for
cross-platform SSH runtime artifacts, and contains spontaneous Claude SDK
generations without terminating the persistent session.

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
  - Size: 40,837,976 bytes (about 39 MB)
  - SHA-256: `728055f697b8698d4879cb02982d2d7c580dc76bdd8d067142b782a0005ed700`
- `Matrix.Co-windows-x64-setup.exe`
  - Architecture: Windows x64
  - Size: 14,617,134 bytes (about 14 MB)
  - SHA-256: `54478c46daab24dad529a6dc9d90ed61720225e383454d485a5de0ece62a35cd`
- `Matrix.Co-windows-x64-portable.zip`
  - Architecture: Windows x64
  - Size: 48,920,051 bytes (about 47 MB)
  - SHA-256: `382343a29102abeac00004558d6e1c33f2df47e6af32248366ce87f02dc67b82`

See `SHA256SUMS.txt` for the combined checksum list.
