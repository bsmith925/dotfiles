# Global agent instructions

Starter global context for pi. Edit freely; this applies to every project
unless a project-level AGENTS.md or CLAUDE.md overrides it.

## Environment
- macOS, zsh. Primary local model is served by the `ninfer` provider
  (`qwen3.8-27b`). Keep answers terse and concrete; lead with the result.
- Prefer editing existing files over creating new ones. Match each project's
  existing style and layout.

## Python (most projects here)
- Use `uv` for environments and dependencies, not `pip` or `poetry`.
  (`uv run`, `uv add`, `uv sync`.)
- Lint and format with `ruff`; type-check where a project already does.
- Run tests with `pytest`. Do not claim tests pass without running them.

## Version control
- GitHub via `gh`; GitLab (git.getwellnetwork.com) via `glab`. Use the
  installed `glab` and `jira` skills for merge requests and tickets.
- Do not commit on the default branch; branch first. Never commit secrets,
  credentials, tokens, or real customer/patient data.

## Working style
- For non-trivial changes, use `/plan` first, then implement.
- Show diffs for review. Ask before destructive or irreversible actions.
