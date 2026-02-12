# Bundled Binaries: ffmpeg & gifsicle

The app bundles **ffmpeg** (video-to-GIF) and **gifsicle** (GIF optimization) as
static binaries so end users don't need to install anything.

> **Preferred approach:** Build from source via the CI workflow (see below).
> Pre-built binaries are documented as a fallback only.

---

## Pinned versions

| Binary   | Version   | Source                                            | License |
|----------|-----------|---------------------------------------------------|---------|
| ffmpeg   | **7.1.1** | https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz  | LGPL 2.1+ (our build) |
| gifsicle | **1.96**  | https://github.com/kohler/gifsicle (tag `v1.96`)  | GPL 2   |

### Archive checksums

| File                      | SHA256                                                             |
|---------------------------|--------------------------------------------------------------------|
| `ffmpeg-7.1.1.tar.xz`    | `733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1` |

> gifsicle is built from the pinned Git tag; verify the commit hash from GitHub.

---

## Licensing

**ffmpeg** is built as **LGPL 2.1+** (no `--enable-gpl`, no GPL-only libraries
like x264/x265). This avoids copyleft obligations on the app itself. We only
need the core codecs, GIF muxer, and video filters (`palettegen`, `paletteuse`,
`scale`, `fps`) which are all LGPL.

**gifsicle** is **GPL 2**. Because it ships as a separate executable invoked as
a subprocess (not linked), this is generally acceptable. However, you must still
distribute gifsicle's source code (or a written offer) alongside the app.
The CI workflow archives the source alongside the built binary for this purpose.

> If GPL bundling is a concern, lossy compression can be made optional / removed,
> since ffmpeg alone produces the GIF.

---

## Where to place binaries

| Platform    | ffmpeg                              | gifsicle                              |
|-------------|-------------------------------------|---------------------------------------|
| **macOS**   | `macos/Runner/Resources/ffmpeg`     | `macos/Runner/Resources/gifsicle`     |
| **Windows** | next to `.exe`: `data/ffmpeg.exe`   | next to `.exe`: `data/gifsicle.exe`   |
| **Linux**   | next to executable: `lib/ffmpeg`    | next to executable: `lib/gifsicle`    |

`BinaryResolver` (`lib/services/binary_resolver.dart`) checks these paths first,
then falls back to system PATH.

---

## Building from source (recommended)

A GitHub Actions workflow at `.github/workflows/build-binaries.yml` builds both
tools from source **and** builds the full Flutter app for all three platforms.

### What the workflow does

For each platform:

1. Downloads ffmpeg source tarball, verifies SHA256
2. Clones gifsicle at the pinned Git tag
3. Configures ffmpeg as a **minimal LGPL static build** (only the codecs,
   muxers, demuxers, and filters needed for GIF conversion)
4. Builds gifsicle from source
5. Records `ffmpeg -version` and `gifsicle --version` in build logs
6. Computes SHA256 of every output binary
7. Uploads standalone binary artifacts (binaries + checksums + gifsicle source)
8. **Builds the Flutter app** (`flutter build <platform> --release`)
9. **Injects the freshly-built binaries** into the app bundle
10. Verifies the bundled binaries are functional inside the app
11. **Uploads a ready-to-distribute app artifact** (`.zip` / `.tar.gz`)

### Platforms & artifacts

| Runner             | Arch            | Binary artifact             | App artifact |
|--------------------|-----------------|-----------------------------|-------------|
| `macos-14`         | arm64 (Apple Silicon) | `binaries-macos-arm64` | `app-macos-arm64` (.zip containing .app) |
| `macos-13`         | x86_64 (Intel)  | `binaries-macos-x86_64`     | `app-macos-x86_64` (.zip containing .app) |
| `ubuntu-22.04`     | x86_64          | `binaries-linux-x86_64`     | `app-linux-x86_64` (.tar.gz bundle) |
| `windows-latest`   | x86_64          | `binaries-windows-x86_64`   | `app-windows-x86_64` (.zip) |

### Running the workflow

Push to the repo (or trigger manually via `workflow_dispatch`), then download
the app artifacts from the Actions tab. They are ready to distribute.

---

## Verification checklist (per platform)

When placing binaries — whether from CI or a fallback source — always:

1. **Verify archive SHA256** against the pinned value (for ffmpeg source tarball)
2. **Verify extracted binary SHA256** against the CI-produced `checksums.sha256`
3. **Check version output** matches expectations:
   ```
   ./ffmpeg -version   # should show "ffmpeg version 7.1.1"
   ./gifsicle --version # should show "LCDF Gifsicle 1.96"
   ```
4. **Record in CI logs** — the workflow does this automatically
5. **Quarantine removal (macOS):** `xattr -cr ./ffmpeg ./gifsicle`

---

## Fallback: pre-built binaries (with hash pinning)

Use these **only** if you cannot build from source. Always verify SHA256.

### Trust tiers

| Tier       | Source | Notes |
|------------|--------|-------|
| Preferred  | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases) | Linux + Windows, publishes `checksums.sha256` |
| Preferred  | [John Van Sickle](https://johnvansickle.com/ffmpeg/) | Linux static builds, multiple arches |
| Preferred  | Homebrew / system package manager | macOS + Linux, for gifsicle |
| Preferred  | [lcdf.org/gifsicle](https://www.lcdf.org/gifsicle/) | Official gifsicle source tarball |
| Fallback   | [Evermeet](https://evermeet.cx/ffmpeg/) | macOS Intel only, verify GPG sig |
| Fallback   | [eternallybored.org](https://eternallybored.org/misc/gifsicle/) | Windows gifsicle, verify hash |
| Fallback   | [Gyan.dev](https://www.gyan.dev/ffmpeg/builds/) | Windows ffmpeg, verify hash |
| **Avoid**  | FFbinaries | Not suitable for shipped/bundled binaries |

### BtbN (Linux + Windows ffmpeg)

Use **LGPL** builds (not GPL) to avoid copyleft on your app:

```
# Example: Linux x86_64 LGPL static
ffmpeg-master-latest-linux64-lgpl.tar.xz
# Checksum file at same release:
checksums.sha256
```

Always cross-reference the SHA256 from the `checksums.sha256` asset in the same
release.

### Evermeet (macOS ffmpeg — fallback)

GPG-signed. Intel x86_64 only (runs via Rosetta on Apple Silicon).
No native ARM builds are planned by the maintainer.

```bash
# Download + verify
curl -JL -o ffmpeg.zip "https://evermeet.cx/ffmpeg/getrelease/zip"
curl -JL -o ffmpeg.zip.sig "https://evermeet.cx/ffmpeg/getrelease/zip/sig"
# Import key: curl https://evermeet.cx/ffmpeg/0x1A660874.asc | gpg --import
gpg --verify ffmpeg.zip.sig ffmpeg.zip
```

---

## Quick local setup (macOS, for development)

For local dev/testing you can use the helper script:

```bash
cd macos/Runner/Resources
./fetch_macos_binaries.sh
```

This fetches from Evermeet + Homebrew. For production builds, use the CI
workflow instead.
