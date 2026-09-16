#!/usr/bin/env bash
# Lean profile: VPS / shared / constrained machines.
# No Rust, Go, NerdFont, or ghostty. Disables heavy LSPs via ~/.nvim_lean.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: the lean profile is Linux-only (detected: $(uname -s)); on macOS use ./install.sh" >&2
  exit 1
fi

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"

maybe_sudo() { [ "$(id -u)" -eq 0 ] && "$@" || sudo "$@"; }

install_packages() {
  maybe_sudo apt-get update -qq
  maybe_sudo apt-get install -y git curl unzip tmux ripgrep fd-find build-essential
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

link_packages() {
  local pkg src dst
  for pkg in nvim tmux shell; do
    echo "linking $pkg..."
    while IFS= read -r src; do
      dst="$HOME/${src#"$DOTFILES/$pkg/"}"
      mkdir -p "$(dirname "$dst")"
      # A real file here is a machine's own config — keep a copy, don't clobber it.
      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
        echo "  backed up existing $dst"
      fi
      ln -sfn "$src" "$dst"
    done < <(find "$DOTFILES/$pkg" -type f)
  done
  # tmux reads ~/.tmux.conf before ~/.config/tmux/tmux.conf, so a leftover one
  # silently shadows the linked config.
  if [ -e "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; then
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
    echo "  moved aside ~/.tmux.conf (it would shadow ~/.config/tmux/tmux.conf)"
  fi
}

install_tmux_plugins() {
  # Clone TPM and every `@plugin` in tmux.conf (resurrect, continuum) into TPM's
  # plugin dir. Plain git rather than TPM's installer, which needs a tmux server.
  local dir="$HOME/.config/tmux/plugins" plugin name
  mkdir -p "$dir"
  for plugin in $(sed -n "s/^set -g @plugin '\([^']*\)'.*/\1/p" "$DOTFILES/tmux/.config/tmux/tmux.conf"); do
    name="${plugin##*/}"
    if [ -d "$dir/$name" ]; then
      echo "tmux plugin $name already installed"
    else
      echo "installing tmux plugin $name..."
      git clone --quiet "https://github.com/$plugin" "$dir/$name"
    fi
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
link_packages
install_tmux_plugins
wire_shell

touch "$HOME/.nvim_lean"

echo "done (lean profile). heavy LSPs disabled."
echo "open a new shell and run: tmux new -A -s dev"
