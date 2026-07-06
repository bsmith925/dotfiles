#!/usr/bin/env bash
# Full install: nvim + tmux + shell + Rust + Go + Node + gh + lazygit + tree-sitter
#               + fzf + NerdFont + ghostty (terminal + config)
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

install_gh() {
  # GitHub CLI — used for auth + SSH key setup. User-scoped, no sudo.
  if [ -x "$HOME/.local/bin/gh" ] || command -v gh &>/dev/null; then
    echo "gh already installed: $(gh --version 2>/dev/null | head -1)"; return
  fi
  echo "installing gh ($ARCH)..."
  local gh_arch
  case "$ARCH" in
    x86_64)  gh_arch="amd64" ;;
    aarch64) gh_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for gh install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://api.github.com/repos/cli/cli/releases/latest" \
    | grep -oP '"tag_name": "v\K[^"]*')
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/cli/cli/releases/download/v${ver}/gh_${ver}_linux_${gh_arch}.tar.gz" \
    -o "$tmp/gh.tar.gz"
  tar -xf "$tmp/gh.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/gh_${ver}_linux_${gh_arch}/bin/gh" "$HOME/.local/bin/gh"
  rm -rf "$tmp"
  echo "installed $("$HOME/.local/bin/gh" --version | head -1)"
}

install_lazygit() {
  # LazyVim's git UI (<leader>gg). Single static binary, no sudo.
  if command -v lazygit &>/dev/null; then
    echo "lazygit already installed: $(lazygit --version | head -1)"; return
  fi
  echo "installing lazygit ($ARCH)..."
  local lg_arch
  case "$ARCH" in
    x86_64)  lg_arch="x86_64" ;;
    aarch64) lg_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for lazygit install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
    | grep -oP '"tag_name": "v\K[^"]*')
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_linux_${lg_arch}.tar.gz" \
    -o "$tmp/lazygit.tar.gz"
  tar -xf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
  echo "installed $("$HOME/.local/bin/lazygit" --version | head -1)"
}

install_treesitter() {
  # tree-sitter CLI — lets nvim-treesitter build/install missing parsers.
  if command -v tree-sitter &>/dev/null; then
    echo "tree-sitter already installed: $(tree-sitter --version)"; return
  fi
  echo "installing tree-sitter CLI ($ARCH)..."
  local ts_arch
  case "$ARCH" in
    x86_64)  ts_arch="x64" ;;
    aarch64) ts_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for tree-sitter install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest" \
    | grep -oP '"tag_name": "\K[^"]*')
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/tree-sitter/tree-sitter/releases/download/${ver}/tree-sitter-linux-${ts_arch}.gz" \
    -o "$tmp/tree-sitter.gz"
  gunzip "$tmp/tree-sitter.gz"
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/tree-sitter" "$HOME/.local/bin/tree-sitter"
  rm -rf "$tmp"
  echo "installed tree-sitter $("$HOME/.local/bin/tree-sitter" --version)"
}

install_node() {
  # Node LTS — required for mason to install JS-based LSPs/formatters
  # (e.g. markdownlint-cli2). Extracted under ~/.local/node, no sudo.
  if command -v node &>/dev/null || [ -x "$HOME/.local/node/bin/node" ]; then
    echo "node already installed: $(node --version 2>/dev/null || "$HOME/.local/node/bin/node" --version)"; return
  fi
  echo "installing node LTS ($ARCH)..."
  local node_arch
  case "$ARCH" in
    x86_64)  node_arch="x64" ;;
    aarch64) node_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for node install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://nodejs.org/dist/index.json" \
    | tr '{' '\n' | grep '"lts":"' | head -1 | grep -oP '"version":"\K[^"]*')
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://nodejs.org/dist/${ver}/node-${ver}-linux-${node_arch}.tar.gz" -o "$tmp/node.tar.gz"
  rm -rf "$HOME/.local/node"
  mkdir -p "$HOME/.local/node"
  tar -xf "$tmp/node.tar.gz" -C "$HOME/.local/node" --strip-components=1
  mkdir -p "$HOME/.local/bin"
  local b
  for b in node npm npx; do ln -sfn "$HOME/.local/node/bin/$b" "$HOME/.local/bin/$b"; done
  rm -rf "$tmp"
  echo "installed node $("$HOME/.local/node/bin/node" --version)"
}

install_fzf() {
  # Fuzzy finder used by Snacks/Telescope pickers. Single static binary.
  if command -v fzf &>/dev/null; then
    echo "fzf already installed: $(fzf --version)"; return
  fi
  echo "installing fzf ($ARCH)..."
  local fzf_arch
  case "$ARCH" in
    x86_64)  fzf_arch="amd64" ;;
    aarch64) fzf_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for fzf install" >&2; exit 1 ;;
  esac
  local ver
  ver=$(curl -fsSL "https://api.github.com/repos/junegunn/fzf/releases/latest" \
    | grep -oP '"tag_name": "v\K[^"]*')
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/junegunn/fzf/releases/download/v${ver}/fzf-${ver}-linux_${fzf_arch}.tar.gz" \
    -o "$tmp/fzf.tar.gz"
  tar -xf "$tmp/fzf.tar.gz" -C "$tmp" fzf
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/fzf" "$HOME/.local/bin/fzf"
  rm -rf "$tmp"
  echo "installed fzf $("$HOME/.local/bin/fzf" --version)"
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
install_gh
install_lazygit
install_treesitter
install_node
install_fzf
install_nerdfont
install_ghostty
link_packages
wire_shell

echo ""
echo "done. launch the terminal with: ghostty   (or pick Ghostty from the app menu)"
echo "then, in a new shell, run: tmux new -A -s dev"
echo "first nvim launch will install plugins automatically."
