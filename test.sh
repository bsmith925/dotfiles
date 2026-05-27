#!/usr/bin/env bash
# Smoke tests — run after install.sh or install-lean.sh
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

pass() { echo "  ✓ $1"; (( PASS++ )) || true; }
fail() { echo "  ✗ $1" >&2; (( FAIL++ )) || true; }

# ── syntax ──────────────────────────────────────────────────────────────────
echo "syntax"
for f in install.sh install-lean.sh shell/.aliases shell/.bashrc_extra shell/.zshrc_extra; do
  bash -n "$DOTFILES/$f" \
    && pass "$f" \
    || fail "$f has syntax errors"
done

# ── symlinks ─────────────────────────────────────────────────────────────────
echo "symlinks"
check_link() {
  local path="$1" fragment="$2"
  if [ -L "$path" ] && readlink "$path" | grep -q "$fragment"; then
    pass "$path → dotfiles"
  else
    fail "$path is not a symlink into dotfiles (got: $(readlink "$path" 2>/dev/null || echo 'missing'))"
  fi
}
check_link "$HOME/.config/nvim"               "dotfiles/nvim"
check_link "$HOME/.config/tmux/tmux.conf"     "dotfiles/tmux"
check_link "$HOME/.aliases"                   "dotfiles/shell"
check_link "$HOME/.bashrc_extra"              "dotfiles/shell"

# ── tmux ─────────────────────────────────────────────────────────────────────
echo "tmux"
if command -v tmux &>/dev/null; then
  if tmux -f "$DOTFILES/tmux/.config/tmux/tmux.conf" new-session -d -s _dotfiles_test 2>/dev/null; then
    tmux kill-session -t _dotfiles_test 2>/dev/null || true
    pass "tmux config parses"
  else
    fail "tmux config failed to parse"
  fi
else
  fail "tmux not found"
fi

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

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
