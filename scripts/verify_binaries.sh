#!/usr/bin/env bash
# verify_binaries.sh — Verify bundled ffmpeg/gifsicle binaries.
#
# Usage:
#   ./scripts/verify_binaries.sh <dir-containing-binaries> [checksums.sha256]
#
# What it does:
#   1. Checks that ffmpeg and gifsicle exist and are executable
#   2. Prints version output for each
#   3. Computes SHA256 and optionally compares against a checksums file
#   4. Reports PASS / FAIL

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

BIN_DIR="${1:?Usage: $0 <binary-dir> [checksums.sha256]}"
CHECKSUMS_FILE="${2:-}"

PASS=true

# Determine binary names based on OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  FFMPEG="ffmpeg.exe"
  GIFSICLE="gifsicle.exe"
else
  FFMPEG="ffmpeg"
  GIFSICLE="gifsicle"
fi

echo "=== Verifying binaries in ${BIN_DIR} ==="
echo ""

# ── Existence & executability ──────────────────────────────────────
for bin in "$FFMPEG" "$GIFSICLE"; do
  path="${BIN_DIR}/${bin}"
  if [[ ! -f "$path" ]]; then
    echo -e "${RED}FAIL${NC}: ${bin} not found at ${path}"
    PASS=false
    continue
  fi
  if [[ ! -x "$path" ]]; then
    echo -e "${YELLOW}WARN${NC}: ${bin} exists but is not executable, attempting chmod +x"
    chmod +x "$path"
  fi
  echo -e "${GREEN}  OK${NC}: ${bin} found and executable"
done

echo ""

# ── Version output ─────────────────────────────────────────────────
echo "--- ffmpeg version ---"
"${BIN_DIR}/${FFMPEG}" -version 2>&1 | head -3 || { echo -e "${RED}FAIL${NC}: could not run ffmpeg"; PASS=false; }

echo ""
echo "--- gifsicle version ---"
"${BIN_DIR}/${GIFSICLE}" --version 2>&1 | head -3 || { echo -e "${RED}FAIL${NC}: could not run gifsicle"; PASS=false; }

echo ""

# ── SHA256 ─────────────────────────────────────────────────────────
echo "--- SHA256 hashes ---"
SHASUM_CMD="shasum -a 256"
command -v sha256sum >/dev/null 2>&1 && SHASUM_CMD="sha256sum"

for bin in "$FFMPEG" "$GIFSICLE"; do
  path="${BIN_DIR}/${bin}"
  [[ -f "$path" ]] && $SHASUM_CMD "$path"
done

echo ""

# ── Compare against provided checksums ─────────────────────────────
if [[ -n "$CHECKSUMS_FILE" && -f "$CHECKSUMS_FILE" ]]; then
  echo "--- Comparing against ${CHECKSUMS_FILE} ---"
  pushd "$BIN_DIR" >/dev/null
  if $SHASUM_CMD -c "$CHECKSUMS_FILE"; then
    echo -e "${GREEN}  OK${NC}: All checksums match"
  else
    echo -e "${RED}FAIL${NC}: Checksum mismatch!"
    PASS=false
  fi
  popd >/dev/null
elif [[ -n "$CHECKSUMS_FILE" ]]; then
  echo -e "${YELLOW}WARN${NC}: Checksums file not found: ${CHECKSUMS_FILE}"
fi

echo ""

# ── Result ─────────────────────────────────────────────────────────
if $PASS; then
  echo -e "${GREEN}=== ALL CHECKS PASSED ===${NC}"
  exit 0
else
  echo -e "${RED}=== SOME CHECKS FAILED ===${NC}"
  exit 1
fi
