#!/usr/bin/env bash
# Install JetBrainsMono Nerd Font (monospaced + glyphs) on macOS or Linux.
# Standalone: called by install.sh, but also safe to run on its own.
#
# If NERD_FONT_VERSION is set (install.sh passes the pinned version), install
# exactly that release and track it in a marker file so a version bump triggers
# a reinstall. If unset (standalone run), fall back to the latest release.
set -euo pipefail

FONT_NAME="JetBrainsMono Nerd Font"
FONT_ARCHIVE="JetBrainsMono.tar.xz"
VER="${NERD_FONT_VERSION:-}"
if [ -n "$VER" ]; then
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${VER}/${FONT_ARCHIVE}"
else
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_ARCHIVE}"
fi

case "$(uname -s)" in
  Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
  Linux)  FONT_DIR="$HOME/.local/share/fonts/NerdFonts" ;;
  *) echo "error: unsupported OS $(uname -s) for font install" >&2; exit 1 ;;
esac
MARKER="$FONT_DIR/.jetbrainsmono-version"

# Already installed? When pinned, compare the marker; otherwise fall back to a
# presence check (macOS ships no fontconfig, so fc-list may be absent).
if [ -n "$VER" ]; then
  if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$VER" ]; then
    echo "$FONT_NAME $VER already installed"; exit 0
  fi
else
  if fc-list 2>/dev/null | grep -qi "$FONT_NAME"; then
    echo "$FONT_NAME already installed"; exit 0
  fi
  if ls "$FONT_DIR"/JetBrainsMono*NerdFont* &>/dev/null; then
    echo "$FONT_NAME already installed"; exit 0
  fi
fi

echo "installing $FONT_NAME ${VER:-latest}..."
mkdir -p "$FONT_DIR"
tmp=$(mktemp -d)
curl -fL "$FONT_URL" -o "$tmp/$FONT_ARCHIVE"
tar -xf "$tmp/$FONT_ARCHIVE" -C "$FONT_DIR"
rm -rf "$tmp"
[ -n "$VER" ] && echo "$VER" > "$MARKER"

# Refresh font cache on Linux (macOS registers automatically).
if command -v fc-cache &>/dev/null; then
  fc-cache -f "$FONT_DIR" 2>/dev/null || true
fi
echo "font installed to $FONT_DIR"
