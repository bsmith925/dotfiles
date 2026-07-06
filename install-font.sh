#!/usr/bin/env bash
# Install JetBrainsMono Nerd Font (monospaced + glyphs) on macOS or Linux.
# Standalone: called by install.sh, but also safe to run on its own.
set -euo pipefail

FONT_NAME="JetBrainsMono Nerd Font"
FONT_ARCHIVE="JetBrainsMono.tar.xz"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_ARCHIVE}"

case "$(uname -s)" in
  Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
  Linux)  FONT_DIR="$HOME/.local/share/fonts/NerdFonts" ;;
  *) echo "error: unsupported OS $(uname -s) for font install" >&2; exit 1 ;;
esac

# Already installed? Prefer fc-list (Linux); fall back to a file check
# since macOS ships no fontconfig by default.
if fc-list 2>/dev/null | grep -qi "$FONT_NAME"; then
  echo "$FONT_NAME already installed"; exit 0
fi
if ls "$FONT_DIR"/JetBrainsMono*NerdFont* &>/dev/null; then
  echo "$FONT_NAME already installed"; exit 0
fi

echo "installing $FONT_NAME..."
mkdir -p "$FONT_DIR"
tmp=$(mktemp -d)
curl -fL "$FONT_URL" -o "$tmp/$FONT_ARCHIVE"
tar -xf "$tmp/$FONT_ARCHIVE" -C "$FONT_DIR"
rm -rf "$tmp"

# Linux needs an explicit cache refresh; macOS registers new fonts on its own.
if command -v fc-cache &>/dev/null; then
  fc-cache -f "$FONT_DIR" 2>/dev/null || true
fi
echo "font installed to $FONT_DIR"
