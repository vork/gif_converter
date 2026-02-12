#!/usr/bin/env bash
# fetch_macos_binaries.sh — Download ffmpeg + gifsicle for local macOS dev.
#
# For production builds, use the GitHub Actions workflow instead.
# This script uses Evermeet (ffmpeg) and Homebrew (gifsicle) for convenience.
#
# Run from: macos/Runner/Resources/

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Pinned ffmpeg release from Evermeet ─────────────────────────────
FFMPEG_RELEASE="8.0.1"
FFMPEG_URL="https://evermeet.cx/ffmpeg/ffmpeg-${FFMPEG_RELEASE}.zip"
FFMPEG_SIG_URL="https://evermeet.cx/ffmpeg/ffmpeg-${FFMPEG_RELEASE}.zip.sig"

echo "=== Fetching ffmpeg ${FFMPEG_RELEASE} (Evermeet) ==="
curl -L -o /tmp/ffmpeg-macos.zip "$FFMPEG_URL"

# GPG verification (if gpg is available and key is imported)
if command -v gpg >/dev/null 2>&1; then
  echo "Attempting GPG signature verification..."
  curl -L -o /tmp/ffmpeg-macos.zip.sig "$FFMPEG_SIG_URL" 2>/dev/null || true
  if [[ -f /tmp/ffmpeg-macos.zip.sig ]]; then
    # Import Evermeet key if not already present
    curl -s https://evermeet.cx/ffmpeg/0x1A660874.asc | gpg --import 2>/dev/null || true
    if gpg --verify /tmp/ffmpeg-macos.zip.sig /tmp/ffmpeg-macos.zip 2>/dev/null; then
      echo "GPG signature: VALID"
    else
      echo "WARNING: GPG signature verification failed or key not trusted"
      echo "  Import key: curl https://evermeet.cx/ffmpeg/0x1A660874.asc | gpg --import"
    fi
    rm -f /tmp/ffmpeg-macos.zip.sig
  fi
else
  echo "gpg not found, skipping signature verification"
fi

# Extract
rm -rf /tmp/ffmpeg-extract
mkdir -p /tmp/ffmpeg-extract
unzip -o -j /tmp/ffmpeg-macos.zip -d /tmp/ffmpeg-extract
FFMPEG_BIN=$(find /tmp/ffmpeg-extract -type f -perm +111 | head -1)
if [[ -z "$FFMPEG_BIN" ]]; then
  FFMPEG_BIN=$(find /tmp/ffmpeg-extract -type f | head -1)
fi
cp "$FFMPEG_BIN" "$SCRIPT_DIR/ffmpeg"
chmod +x "$SCRIPT_DIR/ffmpeg"
rm -rf /tmp/ffmpeg-extract /tmp/ffmpeg-macos.zip

echo "Installed ffmpeg to $SCRIPT_DIR/ffmpeg"
"$SCRIPT_DIR/ffmpeg" -version 2>&1 | head -1
shasum -a 256 "$SCRIPT_DIR/ffmpeg"

# ── gifsicle (from Homebrew) ────────────────────────────────────────
GIFSICLE_EXPECTED_VERSION="1.96"

echo ""
echo "=== Fetching gifsicle (Homebrew, expecting ${GIFSICLE_EXPECTED_VERSION}) ==="
if command -v brew >/dev/null 2>&1; then
  brew list gifsicle >/dev/null 2>&1 || brew install gifsicle
  cp "$(brew --prefix)/bin/gifsicle" "$SCRIPT_DIR/gifsicle"
  chmod +x "$SCRIPT_DIR/gifsicle"

  # Verify version
  INSTALLED_VERSION=$("$SCRIPT_DIR/gifsicle" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [[ "$INSTALLED_VERSION" != "$GIFSICLE_EXPECTED_VERSION" ]]; then
    echo "WARNING: Expected gifsicle ${GIFSICLE_EXPECTED_VERSION}, got ${INSTALLED_VERSION}"
  fi

  echo "Installed gifsicle to $SCRIPT_DIR/gifsicle"
  "$SCRIPT_DIR/gifsicle" --version 2>&1 | head -1
  shasum -a 256 "$SCRIPT_DIR/gifsicle"
else
  echo "ERROR: Homebrew not found."
  echo "  Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "  Then re-run this script."
  exit 1
fi

echo ""
echo "=== Done ==="
echo "You can verify with: ../../scripts/verify_binaries.sh ."
