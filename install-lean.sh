#!/usr/bin/env bash
# Lean profile: VPS / shared / constrained machines.
# No Rust, Go, NerdFont, or ghostty. Disables heavy LSPs via ~/.nvim_lean.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_packages() {
  sudo apt-get update -qq
  sudo apt-get install -y git curl unzip stow tmux ripgrep fd-find build-essential
}

install_nvim() {
  if command -v nvim &>/dev/null && nvim --version | grep -qE "^NVIM v0\.[1-9][0-9]|^NVIM v[1-9]"; then
    echo "neovim already installed: $(nvim --version | head -1)"
    return
  fi
  echo "installing neovim..."
  local tmp; tmp=$(mktemp -d)
  curl -sL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    | tar xz -C "$tmp"
  sudo mv "$tmp"/nvim-linux-x86_64 /opt/nvim
  sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
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
  if [ -f "$zshrc" ] && ! grep -q "zshrc_extra" "$zshrc"; then
    echo '[ -f ~/.zshrc_extra ] && source ~/.zshrc_extra' >> "$zshrc"
  fi
  local bashrc="$HOME/.bashrc"
  if [ -f "$bashrc" ] && ! grep -q "bashrc_extra" "$bashrc"; then
    echo '[ -f ~/.bashrc_extra ] && source ~/.bashrc_extra' >> "$bashrc"
  fi
}

install_packages
install_nvim
stow_packages
wire_shell

# Sentinel: disables heavy extras and plugin auto-update in lazy.lua
touch "$HOME/.nvim_lean"

echo "done (lean profile). heavy LSPs disabled."
echo "open a new shell and run: tmux new -A -s dev"
