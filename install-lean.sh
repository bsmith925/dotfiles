#!/usr/bin/env bash
# Lean profile for shared/constrained machines.
# Same symlinks as install.sh but skips heavy LSPs and disables plugin auto-update.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_packages() {
  sudo apt-get update -qq
  sudo apt-get install -y git curl unzip stow tmux ripgrep fd-find build-essential
}

install_nvim() {
  if command -v nvim &>/dev/null && nvim --version | grep -q "^NVIM v0\.[1-9][0-9]"; then
    echo "neovim already installed: $(nvim --version | head -1)"
    return
  fi
  echo "installing neovim..."
  local tmp
  tmp=$(mktemp -d)
  curl -sL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    | tar xz -C "$tmp"
  sudo mv "$tmp"/nvim-linux-x86_64 /opt/nvim
  sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
}

stow_packages() {
  # pre-create dirs stow would otherwise swallow wholesale
  mkdir -p "$HOME/.config"
  cd "$DOTFILES"
  for pkg in nvim tmux shell; do
    echo "stowing $pkg..."
    stow --target="$HOME" --restow "$pkg"
  done
}

install_packages
install_nvim
stow_packages

# sentinel file that lazy.lua checks — disables heavy extras and auto-update
touch "$HOME/.nvim_lean"

ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ] && ! grep -q "zshrc_extra" "$ZSHRC"; then
  echo '[ -f ~/.zshrc_extra ] && source ~/.zshrc_extra' >> "$ZSHRC"
fi

echo "done (lean profile). heavy LSPs disabled — install per-project as needed."
echo "open a new shell and run: tmux new -A -s dev"
