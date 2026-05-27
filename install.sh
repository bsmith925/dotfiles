#!/usr/bin/env bash
# Full install: nvim + tmux + ghostty + shell + Rust + Go + NerdFont
set -euo pipefail

# Linux only — macOS support not wired yet
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: this script only supports Linux (detected: $(uname -s))" >&2
  exit 1
fi

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"   # x86_64 or aarch64

# Run with sudo when not root (containers run as root; desktops don't)
maybe_sudo() { [ "$(id -u)" -eq 0 ] && "$@" || sudo "$@"; }

install_packages() {
  maybe_sudo apt-get update -qq
  maybe_sudo apt-get install -y \
    git curl unzip tmux ripgrep fd-find \
    build-essential xclip fontconfig
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

install_rust() {
  if command -v rustc &>/dev/null || [ -x "$HOME/.cargo/bin/rustc" ]; then
    echo "rust already installed: $(~/.cargo/bin/rustc --version 2>/dev/null || rustc --version)"; return
  fi
  echo "installing rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  "$HOME/.cargo/bin/rustup" component add rust-analyzer
}

install_go() {
  local gobin="$HOME/.local/go/bin/go"
  if [ -x "$gobin" ]; then
    echo "go already installed: $("$gobin" version)"; return
  fi
  echo "installing go ($ARCH)..."
  local go_arch
  case "$ARCH" in
    x86_64)  go_arch="amd64" ;;
    aarch64) go_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for go install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://go.dev/dl/?mode=json" \
    | tr -d ' \t' | grep -o '"version":"go[^"]*"' | head -1 | cut -d'"' -f4)
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://go.dev/dl/${ver}.linux-${go_arch}.tar.gz" -o "$tmp/go.tar.gz"
  mkdir -p "$HOME/.local"
  tar -xf "$tmp/go.tar.gz" -C "$HOME/.local/"
  rm -rf "$tmp"
  echo "installed $("$gobin" version)"
}

install_nerdfont() {
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    echo "JetBrainsMono Nerd Font already installed"; return
  fi
  echo "installing JetBrainsMono Nerd Font..."
  mkdir -p "$HOME/.local/share/fonts/NerdFonts"
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
    -o "$tmp/JetBrainsMono.tar.xz"
  tar -xf "$tmp/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/NerdFonts/"
  fc-cache -f "$HOME/.local/share/fonts/" 2>/dev/null || true
  rm -rf "$tmp"
  echo "font installed"
}

link_packages() {
  local pkg src dst
  for pkg in nvim tmux ghostty shell; do
    echo "linking $pkg..."
    while IFS= read -r src; do
      dst="$HOME/${src#"$DOTFILES/$pkg/"}"
      mkdir -p "$(dirname "$dst")"
      ln -sfn "$src" "$dst"
    done < <(find "$DOTFILES/$pkg" -type f)
  done
}

wire_shell() {
  local bashrc="$HOME/.bashrc"
  [ -f "$bashrc" ] && ! grep -q "bashrc_extra" "$bashrc" \
    && echo '[ -f ~/.bashrc_extra ] && source ~/.bashrc_extra' >> "$bashrc"
  local zshrc="$HOME/.zshrc"
  [ -f "$zshrc" ] && ! grep -q "zshrc_extra" "$zshrc" \
    && echo '[ -f ~/.zshrc_extra ] && source ~/.zshrc_extra' >> "$zshrc"
}

install_packages
install_nvim
install_rust
install_go
install_nerdfont
link_packages
wire_shell

echo ""
echo "done. open a new shell and run: tmux new -A -s dev"
echo "first nvim launch will install plugins automatically."
