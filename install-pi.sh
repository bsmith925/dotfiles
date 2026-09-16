#!/usr/bin/env bash
# Set up the pi coding agent (https://github.com/earendil-works/pi).
# Standalone and cross-platform (macOS/Linux). Three steps:
#   1. link the tracked pi config from this repo into ~/.pi/agent
#   2. install the pi binary (needs Node/npm)
#   3. install the pi extensions that config alone can't provide
#
# install.sh also links the pi config (via link_packages); this script
# additionally installs the binary and npm-published extensions. Every step is
# idempotent.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. link tracked pi config into ~/.pi/agent ───────────────────────────────
# Per-file symlinks, same convention as install.sh's link_packages(). Only the
# files tracked in this repo are linked; runtime/secret files (auth.json,
# sessions/, models-store.json) and the externally managed mtplx extension are
# left untouched.
if [ -d "$DOTFILES/pi" ]; then
  echo "linking pi config..."
  while IFS= read -r src; do
    dst="$HOME/${src#"$DOTFILES/pi/"}"
    mkdir -p "$(dirname "$dst")"
    # A real file here is a machine's own config — keep a copy, don't clobber it.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
      echo "  backed up existing $dst"
    fi
    ln -sfn "$src" "$dst"
  done < <(find "$DOTFILES/pi" -type f)
fi

# ── 2. install the pi binary ─────────────────────────────────────────────────
if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not found. Run ./install.sh first, which sets up Node" >&2
  echo "       (Linux: pinned LTS; macOS: Homebrew)." >&2
  exit 1
fi
if command -v pi >/dev/null 2>&1; then
  echo "pi already installed ($(pi --version 2>/dev/null || echo '?')); 'pi update self' to upgrade"
else
  echo "installing @earendil-works/pi-coding-agent..."
  npm install -g @earendil-works/pi-coding-agent
fi

# ── 3. install pi extensions ─────────────────────────────────────────────────
# pi-vetter is installed first so it can vet the supply chain of the rest.
# Non-fatal: a failure here (offline, registry hiccup) leaves the linked config
# intact, and each is safe to re-run.
PI_EXTENSIONS=(
  pi-vetter                            # supply-chain vetting first (OSV, sigstore, patterns)
  pi-lens                              # real-time lint / type-check / format feedback (ruff, etc.)
  pi-web-access                        # web search, URL fetch, GitHub clone, PDF/YouTube extraction
  @juicesharp/rpiv-ask-user-question   # structured questions instead of guessing
  @juicesharp/rpiv-todo                # persistent todo overlay (survives compaction)
  pi-mcp-adapter                       # one proxy tool to any MCP server (ready for future servers)
  @plannotator/pi-extension            # plan review with a local browser UI (annotate/approve)
)
for pkg in "${PI_EXTENSIONS[@]}"; do
  echo "pi install npm:$pkg"
  pi install "npm:$pkg" || echo "warning: failed to install $pkg (continuing)" >&2
done

echo ""
echo "pi setup complete. Config is linked from $DOTFILES/pi into ~/.pi/agent."
echo "note: pi-web-access web search needs an API key — set one per its README."
echo "      pi-mcp-adapter is installed but idle until you configure an MCP server."
echo "      plannotator opens a local browser UI for plan review (no account needed)."
