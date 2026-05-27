#!/usr/bin/env bash
# Lean profile: VPS / shared / constrained machines.
# No Rust, Go, NerdFont, or ghostty. Disables heavy LSPs via ~/.nvim_lean.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: this script only supports Linux (detected: $(uname -s))" >&2
  exit 1
fi

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"

maybe_sudo() { [ "$(id -u)" -eq 0 ] && "$@" || sudo "$@"; }

install_packages() {
  maybe_sudo apt-get update -qq
  maybe_sudo apt-get install -y git curl unzip stow tmux ripgrep fd-find build-essential
}

install_nvim() {
  if command -v nvim &>/dev/null && nvim --version | grep -qE "^NVIM v0\.[1-9][0-9]|^NVIM v[1-9]"; then
    echo "neovim already installed: $(nvim --version | head -1)"; return
  fi
  local tarball dir
  case "$ARCH" in
    x86_64)  tarball="nvim-linux-x86_64.tar.gz"; dir="nvim-linux-x86_64" ;;
    aarch64) tarball="nvim-linux-arm64.tar.gz";  dir="nvim-linux-arm64"  ;;
    *) echo "error: unsupported arch $ARCH for nvim install" >&2; exit 1 ;;
  esac
  echo "installing neovim ($ARCH)..."
  local tmp; tmp=$(mktemp -d)
  curl -sL "https://github.com/neovim/neovim/releases/latest/download/${tarball}" \
    | tar xz -C "$tmp"
  maybe_sudo mv "$tmp/$dir" /opt/nvim
  maybe_sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
}

stow_packages() {
  mkdir -p "$HOME/.config"
  cd "$DOTFILES"
  for pkg in nvim tmux shell; do
    echo "stowing $pkg..."
    stow --target="$HOME" --restow "$pkg"
  done
}

wire_shell() {
  local zshrc="$HOME/.zshrc"
  [ -f "$zshrc" ] && ! grep -q "zshrc_extra" "$zshrc" \
    && echo '[ -f ~/.zshrc_extra ] && source ~/.zshrc_extra' >> "$zshrc"
  local bashrc="$HOME/.bashrc"
  [ -f "$bashrc" ] && ! grep -q "bashrc_extra" "$bashrc" \
    && echo '[ -f ~/.bashrc_extra ] && source ~/.bashrc_extra' >> "$bashrc"
}

install_packages
install_nvim
stow_packages
wire_shell

touch "$HOME/.nvim_lean"

echo "done (lean profile). heavy LSPs disabled."
echo "open a new shell and run: tmux new -A -s dev"
