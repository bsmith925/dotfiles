# dotfiles

Personal development environment: Neovim (LazyVim), tmux, the ghostty terminal,
and shell config, plus a one-shot installer that provisions the tools they
depend on. Runs on Debian/Ubuntu-based Linux (developed on Linux Mint), Arch Linux, and
macOS (Apple Silicon and Intel).

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
| `Brewfile`        | macOS packages `install.sh` installs via Homebrew          |
| `install-font.sh` | Standalone JetBrainsMono Nerd Font installer (Linux/macOS) |
| `install-pi.sh`   | Standalone pi coding agent setup (Linux/macOS)             |
| `test.sh`         | Smoke tests run after an install                           |
| `renovate.json`   | Automated version-bump PRs for pinned tools               |

Configs are applied as symlinks back into this repo, so edits to a linked file
are edits to the repo. A real file already at a link target (a machine's own
config) is renamed to `<name>.bak.<timestamp>` rather than overwritten.

## Install

```sh
git clone git@github.com:bsmith925/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The full installer sets up: Neovim, tmux, ripgrep, fd, Rust (rustup), Go, Node
LTS, gh (GitHub CLI), lazygit, the tree-sitter CLI, fzf, the JetBrainsMono Nerd
Font, the ghostty terminal, and the tmux plugins. Every step is idempotent, so
re-running only changes what is missing or out of date.

- **Linux:** apt (Debian/Ubuntu) or pacman (Arch) packages plus pinned release
  binaries. Language toolchains and CLIs install under `~/.local` (no sudo);
  system packages and ghostty use sudo.
- **macOS:** needs [Homebrew](https://brew.sh) first. Tools and the font come
  from the `Brewfile` and ghostty from its cask. Existing packages are never
  upgraded; run `brew upgrade` for that.

When it finishes:

```sh
ghostty                 # launch the terminal (or pick Ghostty from the app menu)
tmux new -A -s dev      # in a new shell
```

The first Neovim launch installs plugins automatically.

## Linux vs macOS

Everything keys off `uname -s` (`Linux` / `Darwin`); shell files use the
equivalent built-in `$OSTYPE`. The differences:

| Where                  | Linux                                  | macOS                                      |
| ---------------------- | -------------------------------------- | ------------------------------------------ |
| `install.sh`           | apt/pacman + pinned binaries           | `Brewfile` + ghostty cask                  |
| `install-lean.sh`      | supported                              | not supported (use `install.sh`)           |
| `tmux.conf` clipboard  | `xclip` / `xsel`                       | `pbcopy`                                   |
| `.bashrc_extra` / `.zshrc_extra` | —                            | loads Homebrew (`/opt/homebrew` or `/usr/local`) if it isn't on `PATH` |
| `.aliases`             | `fd` -> `fdfind`                       | `fd` is already `fd`                       |
| ghostty                | —                                      | left Option acts as Alt (tmux `M-h`/`M-l`) |

## tmux sessions across reboots

[tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) and
[tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) are installed
(via [TPM](https://github.com/tmux-plugins/tpm), into `~/.config/tmux/plugins`)
by both installers. Sessions, windows, pane layouts, working directories, and
pane contents are saved every 15 minutes and restored when the tmux server next
starts, e.g. the first `tmux new -A -s dev` after a reboot. Manual save/restore:
`prefix + C-s` / `prefix + C-r`. Only a short list of programs (vim/nvim, less,
man, top, ...) is relaunched in restored panes.

tmux reads `~/.tmux.conf` in preference to `~/.config/tmux/tmux.conf`, so the
installers move an existing `~/.tmux.conf` aside.

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
`AGENTS.md`, guardrail extensions (git-checkpoint, permission-gate,
protected-paths, dirty-repo-guard), and the subagent extension with its agents
and workflow prompts. Todo and plan mode come from npm extensions instead
(`rpiv-todo` and Plannotator, installed by `install-pi.sh`). Runtime and secret
files (`auth.json`,
`sessions/`, `models-store.json`) are gitignored; the externally managed
`mtplx-request-policy.ts` extension is left in place, not tracked.

Full setup, including the pi binary and the npm-published extensions:

```sh
./install-pi.sh
```

`./install.sh` also links the pi config as part of the full install (Linux and
macOS); `install-pi.sh` additionally installs `pi` plus its extensions: `pi-vetter`, `pi-lens`, `pi-web-access`,
`rpiv-ask-user-question`, `rpiv-todo`, `pi-mcp-adapter`, and Plannotator
(`@plannotator/pi-extension`). `pi-web-access` web search needs an API key;
`pi-mcp-adapter` stays idle until an MCP server is configured; Plannotator opens
a local browser UI for plan review and replaces the shipped `plan-mode` (removed
to avoid a `--plan` flag conflict).

### CliffCompaction proxy

The `ninfer` provider routes through [CliffCompaction](https://github.com/nguyenvuthientrang/cliffcompaction),
a local API proxy that autocompacts long sessions under a token budget
(installed via `uv tool install cliffcompaction`, run as a launchd daemon on
`127.0.0.1:8257`). `models.json` points `ninfer.baseUrl` at the proxy, which
forwards to the real ninfer server; `settings.json` disables pi's native
auto-compaction (`compaction.enabled: false`) so only the proxy rewrites
history. Manual `/compact` still works.

- `cliff status` / `cliff watch` — health / live request view
- `cliff restart` — pick up an upgrade
- `cliff disable` — remove the daemon
- Reconfigure: `cliff enable --no-env --port 8257 --threshold 128000 --openai-upstream http://192.168.1.184:8080`
  (knobs: `--threshold`, `--keep-recent`, `--result-max-chars`, `--drop-thinking`), then `cliff restart`
- Log: `~/Library/Logs/cliffcompaction.log`
- Fail-open: if the daemon is down or can't parse a request, traffic passes
  through unmodified. The prefix store is in-memory; after a daemon restart
  the first request of a long session re-derives its prefix (one extra
  compaction, no correctness impact).
- Rollback: `cliff disable`, then revert `ninfer.baseUrl` to
  `http://192.168.1.184:8080/v1` and `compaction.enabled` to `true`.

## Version management

- **System tools** are pinned in a single block at the top of `install.sh`.
  To upgrade one, bump its line and re-run `./install.sh` — the version-aware
  guards replace the installed binary. Each pin carries a `# renovate:` comment
  so [Renovate](https://docs.renovatebot.com/) can open grouped bump PRs
  (config in `renovate.json`).
- **Neovim plugins** are pinned in `nvim/.config/nvim/lazy-lock.json`. Update
  with `:Lazy update` inside Neovim, then commit the changed lock file.
- **Rust** is managed by rustup; run `rustup update` to bump it.
- **macOS tools** aren't pinned: Homebrew ships current releases, so the pins
  and Renovate cover Linux only. Upgrade with `brew upgrade`.
- **tmux plugins** track their default branches; `prefix + U` updates them.

## Testing

```sh
./test.sh
```

Checks script syntax, that the expected symlinks resolve into this repo, that
the tmux and Neovim configs load (tmux on a private server, so a running tmux
isn't touched), that the tmux plugins are installed and not shadowed by a
`~/.tmux.conf`, and that each installed tool actually runs.
A tool that is legitimately absent (lean profile, or unsupported system) is
skipped rather than failed.

CI (`.github/workflows/ci.yml`) runs the full install plus `test.sh` on
Ubuntu x86_64, Ubuntu arm64, Debian Bookworm, Arch, macOS arm64, and macOS
x86_64 on every push and pull request.
