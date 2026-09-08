# dotfiles

Personal development environment: Neovim (LazyVim), tmux, the ghostty terminal,
and shell config, plus a one-shot installer that provisions the tools they
depend on. Targets Debian/Ubuntu-based Linux (developed on Linux Mint); the font
and pi installers also support macOS.

## Layout

| Path              | What it holds                                              |
| ----------------- | ---------------------------------------------------------- |
| `nvim/`           | Neovim config (LazyVim) -> `~/.config/nvim`                |
| `tmux/`           | tmux config -> `~/.config/tmux`                            |
| `ghostty/`        | ghostty terminal config -> `~/.config/ghostty`            |
| `shell/`          | `.aliases`, `.bashrc_extra`, `.zshrc_extra` -> `~`         |
| `pi/`             | pi coding agent config -> `~/.pi/agent`                    |
| `install.sh`      | Full install: tools + symlinks + shell wiring             |
| `install-lean.sh` | Lean profile for constrained machines (VPS, containers)   |
| `install-font.sh` | Standalone JetBrainsMono Nerd Font installer (Linux/macOS) |
| `install-pi.sh`   | Standalone pi coding agent setup (Linux/macOS)             |
| `test.sh`         | Smoke tests run after an install                           |
| `renovate.json`   | Automated version-bump PRs for pinned tools               |

Configs are applied as symlinks back into this repo, so edits to a linked file
are edits to the repo.

## Install

```sh
git clone git@github.com:bsmith925/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The full installer sets up: Neovim, tmux, ripgrep, fd, Rust (rustup), Go, Node
LTS, gh (GitHub CLI), lazygit, the tree-sitter CLI, fzf, the JetBrainsMono Nerd
Font, and the ghostty terminal. Language toolchains and CLIs install under
`~/.local` (no sudo); apt packages and ghostty use sudo. Every step is
idempotent and version-aware, so re-running only changes what is out of date.

When it finishes:

```sh
ghostty                 # launch the terminal (or pick Ghostty from the app menu)
tmux new -A -s dev      # in a new shell
```

The first Neovim launch installs plugins automatically.

### Lean profile

For a VPS, shared box, or container where the full toolchain is unwanted:

```sh
./install-lean.sh
```

This installs only Neovim, tmux, and the shell config, and writes `~/.nvim_lean`
to disable the heavier LSPs.

## pi coding agent

Config for [pi](https://github.com/earendil-works/pi) lives in `pi/.pi/agent`
and links into `~/.pi/agent`. Tracked: `settings.json` (starts on the local
`ninfer` provider), `models.json` (local provider registry), a global
`AGENTS.md`, guardrail and workflow extensions (git-checkpoint, permission-gate,
protected-paths, dirty-repo-guard, plan-mode, todo), and the subagent extension
with its agents and workflow prompts. Runtime and secret files (`auth.json`,
`sessions/`, `models-store.json`) are gitignored; the externally managed
`mtplx-request-policy.ts` extension is left in place, not tracked.

Full setup, including the pi binary and the npm-published extensions:

```sh
./install-pi.sh
```

On Linux, `./install.sh` also links the pi config as part of the full install.
`install-pi.sh` is the macOS entry point (the full installer is Linux-only) and
installs `pi` plus `pi-vetter`, `pi-lens`, and `pi-web-access`. `pi-web-access`
web search needs an API key; `pi-mcp-adapter` is intentionally left out until
MCP servers are in use.

## Version management

- **System tools** are pinned in a single block at the top of `install.sh`.
  To upgrade one, bump its line and re-run `./install.sh` — the version-aware
  guards replace the installed binary. Each pin carries a `# renovate:` comment
  so [Renovate](https://docs.renovatebot.com/) can open grouped bump PRs
  (config in `renovate.json`).
- **Neovim plugins** are pinned in `nvim/.config/nvim/lazy-lock.json`. Update
  with `:Lazy update` inside Neovim, then commit the changed lock file.
- **Rust** is managed by rustup; run `rustup update` to bump it.

## Testing

```sh
./test.sh
```

Checks script syntax, that the expected symlinks resolve into this repo, that
the tmux and Neovim configs load, and that each installed tool actually runs.
A tool that is legitimately absent (lean profile, or unsupported system) is
skipped rather than failed.

CI (`.github/workflows/ci.yml`) runs the full install plus `test.sh` on
Ubuntu x86_64, Ubuntu arm64, and Debian Bookworm on every push and pull request.
