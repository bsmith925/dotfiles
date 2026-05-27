#!/usr/bin/env bash
# Full install: nvim + tmux + ghostty + shell + Rust + Go + NerdFont
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_packages() {
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y git curl unzip stow tmux ripgrep fd-find build-essential xclip
  elif command -v brew &>/dev/null; then
    brew install git curl stow tmux ripgrep fd
  fi
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

install_rust() {
  if command -v rustc &>/dev/null; then
    echo "rust already installed: $(rustc --version)"
    return
  fi
  echo "installing rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # rust-analyzer for neovim LSP
  "$HOME/.cargo/bin/rustup" component add rust-analyzer
}

install_go() {
  local gobin="$HOME/.local/go/bin/go"
  if [ -x "$gobin" ]; then
    echo "go already installed: $("$gobin" version)"
    return
  fi
  echo "installing go..."
  local ver
  ver=$(curl -fsSL "https://go.dev/dl/?mode=json" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(v['version'] for v in d if v['stable']))")
  local arch; arch=$(uname -m)
  [ "$arch" = "x86_64" ] && arch="amd64"
  [ "$arch" = "aarch64" ] && arch="arm64"
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://go.dev/dl/${ver}.linux-${arch}.tar.gz" -o "$tmp/go.tar.gz"
  tar -xf "$tmp/go.tar.gz" -C "$HOME/.local/"
  rm -rf "$tmp"
  echo "installed $("$gobin" version)"
}

install_nerdfont() {
  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    echo "JetBrainsMono Nerd Font already installed"
    return
  fi
  echo "installing JetBrainsMono Nerd Font..."
  mkdir -p "$HOME/.local/share/fonts/NerdFonts"
  local tmp; tmp=$(mktemp -d)
  curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
    -o "$tmp/JetBrainsMono.tar.xz"
  tar -xf "$tmp/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts/NerdFonts/"
  fc-cache -fv "$HOME/.local/share/fonts/" &>/dev/null
  rm -rf "$tmp"
  echo "font installed"
}

stow_packages() {
  mkdir -p "$HOME/.config"
  cd "$DOTFILES"
  for pkg in nvim tmux ghostty shell; do
    echo "stowing $pkg..."
    stow --target="$HOME" --restow "$pkg"
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
stow_packages
wire_shell

echo ""
echo "done. open a new shell and run: tmux new -A -s dev"
echo "first nvim launch will install plugins automatically."
