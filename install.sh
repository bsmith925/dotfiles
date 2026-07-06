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

# ── pinned tool versions ─────────────────────────────────────────────────────
# Single source of truth. To upgrade a tool: bump its line, commit, and re-run
# ./install.sh — the version-aware guards below will replace the old binary.
# Renovate opens bump PRs automatically (see renovate.json); the `# renovate:`
# comment on the line ABOVE each pin maps it to its upstream source — keep them.
#
# renovate: datasource=github-releases depName=neovim/neovim
NVIM_VERSION=0.12.4
# renovate: datasource=golang-version depName=go
GO_VERSION=1.26.4
# renovate: datasource=github-releases depName=cli/cli
GH_VERSION=2.96.0
# renovate: datasource=github-releases depName=jesseduffield/lazygit
LAZYGIT_VERSION=0.63.0
# renovate: datasource=github-releases depName=tree-sitter/tree-sitter
TREE_SITTER_VERSION=0.26.10
# renovate: datasource=node-version depName=node versioning=node
NODE_VERSION=24.18.0
# renovate: datasource=github-releases depName=junegunn/fzf
FZF_VERSION=0.74.0
# renovate: datasource=github-releases depName=ryanoasis/nerd-fonts
NERD_FONT_VERSION=3.4.0
# renovate: datasource=github-releases depName=mkasberg/ghostty-ubuntu versioning=loose
GHOSTTY_DEB_RELEASE=1.3.1-0-ppa2

# Run with sudo when not root (containers run as root; desktops don't)
maybe_sudo() { [ "$(id -u)" -eq 0 ] && "$@" || sudo "$@"; }

install_packages() {
  maybe_sudo apt-get update -qq
  maybe_sudo apt-get install -y \
    git curl unzip tmux ripgrep fd-find \
    build-essential xclip fontconfig
}

install_nvim() {
  local have; have=$(nvim --version 2>/dev/null | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ "$have" = "$NVIM_VERSION" ]; then
    echo "neovim $NVIM_VERSION already installed"; return
  fi
  local tarball dir
  case "$ARCH" in
    x86_64)  tarball="nvim-linux-x86_64.tar.gz"; dir="nvim-linux-x86_64" ;;
    aarch64) tarball="nvim-linux-arm64.tar.gz";  dir="nvim-linux-arm64"  ;;
    *) echo "error: unsupported arch $ARCH for nvim install" >&2; exit 1 ;;
  esac
  echo "installing neovim $NVIM_VERSION ($ARCH)..."
  local tmp; tmp=$(mktemp -d)
  curl -sL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${tarball}" \
    | tar xz -C "$tmp"
  maybe_sudo rm -rf /opt/nvim
  maybe_sudo mv "$tmp/$dir" /opt/nvim
  maybe_sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
}

install_rust() {
  # Rust is managed by rustup, not pinned here — run `rustup update` to bump.
  if command -v rustc &>/dev/null || [ -x "$HOME/.cargo/bin/rustc" ]; then
    echo "rust already installed: $(~/.cargo/bin/rustc --version 2>/dev/null || rustc --version)"; return
  fi
  echo "installing rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  "$HOME/.cargo/bin/rustup" component add rust-analyzer
}

install_go() {
  local gobin="$HOME/.local/go/bin/go"
  local have; have=$("$gobin" version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
  if [ "$have" = "$GO_VERSION" ]; then
    echo "go $GO_VERSION already installed"; return
  fi
  echo "installing go $GO_VERSION ($ARCH)..."
  local go_arch
  case "$ARCH" in
    x86_64)  go_arch="amd64" ;;
    aarch64) go_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for go install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o "$tmp/go.tar.gz"
  rm -rf "$HOME/.local/go"
  mkdir -p "$HOME/.local"
  tar -xf "$tmp/go.tar.gz" -C "$HOME/.local/"
  rm -rf "$tmp"
  echo "installed $("$gobin" version)"
}

install_gh() {
  # GitHub CLI — used for auth + SSH key setup. User-scoped, no sudo.
  local have; have=$("$HOME/.local/bin/gh" --version 2>/dev/null | head -1 | grep -oP 'gh version \K[0-9.]+' || true)
  if [ "$have" = "$GH_VERSION" ]; then
    echo "gh $GH_VERSION already installed"; return
  fi
  echo "installing gh $GH_VERSION ($ARCH)..."
  local gh_arch
  case "$ARCH" in
    x86_64)  gh_arch="amd64" ;;
    aarch64) gh_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for gh install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${gh_arch}.tar.gz" \
    -o "$tmp/gh.tar.gz"
  tar -xf "$tmp/gh.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/gh_${GH_VERSION}_linux_${gh_arch}/bin/gh" "$HOME/.local/bin/gh"
  rm -rf "$tmp"
  echo "installed $("$HOME/.local/bin/gh" --version | head -1)"
}

install_lazygit() {
  # LazyVim's git UI (<leader>gg). Single static binary, no sudo.
  local have; have=$(lazygit --version 2>/dev/null | grep -oP 'version=\K[0-9.]+' | head -1 || true)
  if [ "$have" = "$LAZYGIT_VERSION" ]; then
    echo "lazygit $LAZYGIT_VERSION already installed"; return
  fi
  echo "installing lazygit $LAZYGIT_VERSION ($ARCH)..."
  local lg_arch
  case "$ARCH" in
    x86_64)  lg_arch="x86_64" ;;
    aarch64) lg_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for lazygit install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${lg_arch}.tar.gz" \
    -o "$tmp/lazygit.tar.gz"
  tar -xf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
  echo "installed $("$HOME/.local/bin/lazygit" --version | head -1)"
}

install_treesitter() {
  # tree-sitter CLI — lets nvim-treesitter build/install missing parsers.
  local have; have=$(tree-sitter --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ "$have" = "$TREE_SITTER_VERSION" ]; then
    echo "tree-sitter $TREE_SITTER_VERSION already installed"; return
  fi
  echo "installing tree-sitter CLI $TREE_SITTER_VERSION ($ARCH)..."
  local ts_arch
  case "$ARCH" in
    x86_64)  ts_arch="x64" ;;
    aarch64) ts_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for tree-sitter install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-linux-${ts_arch}.gz" \
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
  local have; have=$("$HOME/.local/node/bin/node" --version 2>/dev/null | grep -oP 'v\K[0-9.]+' || true)
  if [ "$have" = "$NODE_VERSION" ]; then
    echo "node $NODE_VERSION already installed"; return
  fi
  echo "installing node $NODE_VERSION ($ARCH)..."
  local node_arch
  case "$ARCH" in
    x86_64)  node_arch="x64" ;;
    aarch64) node_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for node install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.gz" -o "$tmp/node.tar.gz"
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
  local have; have=$(fzf --version 2>/dev/null | grep -oP '^[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ "$have" = "$FZF_VERSION" ]; then
    echo "fzf $FZF_VERSION already installed"; return
  fi
  echo "installing fzf $FZF_VERSION ($ARCH)..."
  local fzf_arch
  case "$ARCH" in
    x86_64)  fzf_arch="amd64" ;;
    aarch64) fzf_arch="arm64" ;;
    *) echo "error: unsupported arch $ARCH for fzf install" >&2; exit 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${fzf_arch}.tar.gz" \
    -o "$tmp/fzf.tar.gz"
  tar -xf "$tmp/fzf.tar.gz" -C "$tmp" fzf
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/fzf" "$HOME/.local/bin/fzf"
  rm -rf "$tmp"
  echo "installed fzf $("$HOME/.local/bin/fzf" --version)"
}

install_nerdfont() {
  # Monospaced Nerd Font install lives in a standalone, cross-platform script.
  # Pass the pinned version through; the script is version-aware via a marker.
  NERD_FONT_VERSION="$NERD_FONT_VERSION" "$DOTFILES/install-font.sh"
}

install_ghostty() {
  # GNOME Terminal (Mint's default) can't render Nerd Fonts without huge
  # inter-glyph gaps, so we install ghostty — its config is linked below.
  local want="${GHOSTTY_DEB_RELEASE%%-*}"   # upstream ghostty version, e.g. 1.3.1
  local have; have=$(ghostty --version 2>/dev/null | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [ "$have" = "$want" ]; then
    echo "ghostty $want already installed"; return
  fi
  if ! command -v apt-get &>/dev/null; then
    echo "ghostty auto-install is apt-only; install manually: https://ghostty.org/download"
    return
  fi
  echo "installing ghostty $want..."
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
  if [ -z "$ubu" ]; then
    echo "couldn't determine Ubuntu base; install ghostty manually: https://ghostty.org/download"
    return
  fi
  local deb_arch; deb_arch=$(dpkg --print-architecture)
  # Release tag 1.3.1-0-ppa2 -> asset infix 1.3.1-0.ppa2
  local asset_ver="${GHOSTTY_DEB_RELEASE%-*}.${GHOSTTY_DEB_RELEASE##*-}"
  local url="https://github.com/mkasberg/ghostty-ubuntu/releases/download/${GHOSTTY_DEB_RELEASE}/ghostty_${asset_ver}_${deb_arch}_${ubu}.deb"
  if ! curl -fsSL -o /dev/null -I "$url"; then
    echo "no ghostty .deb for ${deb_arch}/${ubu} at $GHOSTTY_DEB_RELEASE; install manually: https://ghostty.org/download"
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
