#!/bin/bash
set -euo pipefail

# Vendor Zafiro-icons into the build tree without using a git submodule.
# The ISO build fetches the pinned upstream snapshot and copies the actual
# icon files into /usr/share/icons/Zafiro.
ZAFIRO_VERSION="5c7f38ca3b01194104481ffb803111e31851cf5d"
ZAFIRO_URL="https://github.com/zayronxio/Zafiro-icons/archive/${ZAFIRO_VERSION}.tar.gz"
TMP_DIR="${TMPDIR:-/tmp}/zafiro-icons"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
if command -v curl >/dev/null 2>&1; then
  curl -fL "$ZAFIRO_URL" -o "$TMP_DIR/zafiro.tar.gz"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$TMP_DIR/zafiro.tar.gz" "$ZAFIRO_URL"
else
  echo "curl or wget is required to vendor Zafiro-icons" >&2
  exit 1
fi
mkdir -p "$TMP_DIR/extracted"
tar -xzf "$TMP_DIR/zafiro.tar.gz" -C "$TMP_DIR/extracted"
SRC="$(find "$TMP_DIR/extracted" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [[ -z "$SRC" ]]; then
  echo "Could not locate extracted Zafiro-icons directory" >&2
  exit 1
fi
rm -rf "${1:?destination required}"
mkdir -p "${1}"
cp -a "$SRC"/. "${1}/"
rm -rf "$TMP_DIR"
