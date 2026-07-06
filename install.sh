#!/usr/bin/env bash
# Full install: nvim + tmux + shell + Rust + Go + NerdFont + ghostty (terminal + config)
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
  # Monospaced Nerd Font install lives in a standalone, cross-platform script.
  "$DOTFILES/install-font.sh"
}

install_ghostty() {
  # GNOME Terminal (Mint's default) can't render Nerd Fonts without huge
  # inter-glyph gaps, so we install ghostty — its config is linked below.
  if command -v ghostty &>/dev/null; then
    echo "ghostty already installed: $(ghostty --version | head -1)"; return
  fi
  if ! command -v apt-get &>/dev/null; then
    echo "ghostty auto-install is apt-only; install manually: https://ghostty.org/download"
    return
  fi
  echo "installing ghostty..."
  # shellcheck disable=SC1091
  . /etc/os-release
  # Mint & other derivatives report their own VERSION_ID, so map the Ubuntu
  # base codename to the version the community .debs are built against.
  local ubu
  case "${UBUNTU_CODENAME:-}" in
    noble)    ubu=24.04 ;;
    oracular) ubu=24.10 ;;
    plucky)   ubu=25.04 ;;
    questing) ubu=25.10 ;;
    *)        ubu="${VERSION_ID:-}" ;;   # real Ubuntu already uses 24.04-style
  esac
  local deb_arch; deb_arch=$(dpkg --print-architecture)
  local url
  url=$(curl -fsSL "https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest" \
    | grep -oP '"browser_download_url": "\K[^"]*' \
    | grep "_${deb_arch}_${ubu}\.deb$" | head -1 || true)
  if [ -z "$url" ]; then
    echo "no ghostty .deb for ${deb_arch}/${ubu}; install manually: https://ghostty.org/download"
    return
  fi
  local tmp; tmp=$(mktemp -d)
  curl -fL "$url" -o "$tmp/ghostty.deb"
  maybe_sudo apt-get install -y "$tmp/ghostty.deb"
  rm -rf "$tmp"
  echo "installed $(ghostty --version | head -1)"
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
  if [ -f "$bashrc" ] && ! grep -q "bashrc_extra" "$bashrc"; then
    echo '[ -f ~/.bashrc_extra ] && source ~/.bashrc_extra' >> "$bashrc"
  fi
  local zshrc="$HOME/.zshrc"
  if [ -f "$zshrc" ] && ! grep -q "zshrc_extra" "$zshrc"; then
    echo '[ -f ~/.zshrc_extra ] && source ~/.zshrc_extra' >> "$zshrc"
  fi
}

install_packages
install_nvim
install_rust
install_go
install_nerdfont
install_ghostty
link_packages
wire_shell

echo ""
echo "done. launch the terminal with: ghostty   (or pick Ghostty from the app menu)"
echo "then, in a new shell, run: tmux new -A -s dev"
echo "first nvim launch will install plugins automatically."
