#!/usr/bin/env bash
# Smoke tests — run after install.sh or install-lean.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; (( PASS++ )) || true; }
fail() { echo "  ✗ $1" >&2; (( FAIL++ )) || true; }

# ── syntax ──────────────────────────────────────────────────────────────────
echo "syntax"
for f in install.sh install-lean.sh install-font.sh install-pi.sh shell/.aliases shell/.bashrc_extra shell/.zshrc_extra; do
  bash -n "$DOTFILES/$f" \
    && pass "$f" \
    || fail "$f has syntax errors"
done

# ── symlinks ─────────────────────────────────────────────────────────────────
echo "symlinks"
check_link() {
  local target="$1" fragment="$2" check="$1"
  while [ "$check" != "/" ]; do
    if [ -L "$check" ] && readlink "$check" | grep -q "$fragment"; then
      pass "$target → dotfiles"; return
    fi
    [ "$check" = "$HOME" ] && break
    check="$(dirname "$check")"
  done
  fail "$target not linked into dotfiles ($(readlink "$target" 2>/dev/null || echo 'missing'))"
}
check_link "$HOME/.config/nvim/init.lua"      "dotfiles/nvim"
check_link "$HOME/.config/tmux/tmux.conf"     "dotfiles/tmux"
check_link "$HOME/.aliases"                   "dotfiles/shell"
check_link "$HOME/.bashrc_extra"              "dotfiles/shell"
check_link "$HOME/.pi/agent/settings.json"    "dotfiles/pi"

# ── tmux ─────────────────────────────────────────────────────────────────────
echo "tmux"
if command -v tmux &>/dev/null; then
  # Private server (-L): a live tmux would ignore -f, and continuum must not
  # restore saved sessions into this one before it's killed.
  if tmux -L _dotfiles_test -f "$DOTFILES/tmux/.config/tmux/tmux.conf" new-session -d 2>/dev/null; then
    tmux -L _dotfiles_test kill-server 2>/dev/null || true
    pass "tmux config parses"
  else
    fail "tmux config failed to parse"
  fi
else
  fail "tmux not found"
fi
[ ! -e "$HOME/.tmux.conf" ] \
  && pass "no ~/.tmux.conf shadowing it" \
  || fail "~/.tmux.conf shadows ~/.config/tmux/tmux.conf — move it aside"
for plugin in tpm tmux-resurrect tmux-continuum; do
  [ -d "$HOME/.config/tmux/plugins/$plugin" ] \
    && pass "tmux plugin $plugin installed" \
    || fail "tmux plugin $plugin missing (re-run the installer)"
done

# ── nvim ─────────────────────────────────────────────────────────────────────
echo "nvim"
if command -v nvim &>/dev/null; then
  if nvim --headless +qa 2>/dev/null; then
    pass "nvim --headless exits cleanly"
  else
    fail "nvim --headless exited with error"
  fi
else
  fail "nvim not found"
fi

# ── tools ─────────────────────────────────────────────────────────────────────
# For every tool install.sh may set up, assert that if it is present it actually
# runs. This catches installed-but-broken binaries (e.g. a release built against
# a newer glibc than the host provides). Tools that are legitimately absent — the
# lean profile, or an unsupported system — are skipped, not failed.
echo "tools"
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/.cargo/bin:$PATH"
check_runs() {   # <name> <cmd> [args...]
  local name="$1"; shift
  if ! command -v "$1" &>/dev/null; then
    echo "  - $name skipped (not installed)"; return
  fi
  if "$@" &>/dev/null; then
    pass "$name runs"
  else
    fail "$name is installed but won't run"
  fi
}
check_runs "rustc"       rustc --version
check_runs "go"          go version
check_runs "gh"          gh --version
check_runs "lazygit"     lazygit --version
check_runs "tree-sitter" tree-sitter --version
check_runs "node"        node --version
check_runs "fzf"         fzf --version
check_runs "rg"          rg --version
check_runs "fdfind"      fdfind --version   # Debian/Ubuntu name
check_runs "fd"          fd --version       # Homebrew name
check_runs "ghostty"     ghostty --version

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
