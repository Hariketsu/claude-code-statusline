# Roadmap

This document records **direction**, not a binding schedule. Items move when they earn their keep against the project principles below.

## Principles

1. **Single-line, scannable** — every segment must earn its width.
2. **Honest data** — git numbers come from git; session stats stay session stats; never mix them under the same glyph.
3. **Bash-first, zero runtime** — one `statusline.sh` + `jq` + optional `git`. No Node/Bun required for the default path.
4. **Fail soft** — a broken segment hides itself; the bar never goes blank because of one field.
5. **Third-party models welcome** — DeepSeek, Grok, CPA gateways, etc. Context limit prefers Claude Code’s JSON / env, not hardcoded model→window tables.

## Current (done)

- [x] Starship-inspired single line, Gruvbox Dark palette
- [x] Model short names (DeepSeek v4 pro/flash, Grok 4.5) + plain-text toggle
- [x] Effort level (`󰧑 low|med|high|xhigh|max`) when present
- [x] Directory basename
- [x] Git branch / detached short SHA (``, Nerd Font `f418`)
- [x] **Real** working-tree line counts via `git diff --shortstat` + `git diff --cached --shortstat` (not `cost.total_lines_*`)
- [x] Context as gauge icon + `pct%/limit` (visual tiers 30/55/85; color by remaining tokens)
- [x] Context limit: `context_window_size` → `$CLAUDE_CODE_MAX_CONTEXT_TOKENS` → `200000`
- [x] Session duration from `cost.total_duration_ms`
- [x] Bash 3.2 (macOS) compatible; `set -uo pipefail`; `printf '%s'`

## Near term

### Docs & packaging

- [ ] Keep README in sync with script behavior (no stale field tables)
- [x] Document third-party 500k setup: `CLAUDE_CODE_MAX_CONTEXT_TOKENS` / `CLAUDE_CODE_AUTO_COMPACT_WINDOW` in `settings.json` `env`
- [ ] Optional install helper script (`install.sh` → `~/.claude/statusline.sh` + print settings snippet)
- [ ] Screenshot / GIF of live statusline (Nerd Font terminal)

### Robustness

- [ ] Smoke tests: fixture JSON files + expected substring checks (CI-friendly)
- [ ] Guard `git` timeouts on huge repos (soft fail → branch only)
- [ ] Optional short git cache (mtime of `.git/HEAD` / index + small TTL) — only if real lag shows up

### UX polish (opt-in, default off unless clearly better)

- [ ] Dirty flag without line counts (`*` / `?`) as optional compact mode
- [ ] Ahead/behind (`↑N` `↓M`) behind a flag — costs an extra git call
- [ ] More model short-name mappings (community PRs welcome)

## Platform: Windows (technical route)

**Goal:** usable on Windows without abandoning the bash-first design.

### Recommended path (default) — implemented & documented

| Layer | Choice |
|-------|--------|
| Runtime | **Git Bash** (Git for Windows) runs the same `statusline.sh` |
| Claude Code | With Git Bash installed, statusline commands often run under Git Bash; use `~/.claude/statusline.sh` or forward-slash paths |
| Dependencies | `bash`, `jq` on PATH inside Git Bash, `git` |
| Terminal | Windows Terminal + a **Nerd Font** (icons: gauge, effort, git branch) |
| UTF-8 | Prefer UTF-8 code page / WT defaults so glyphs render |

**Not required for this path:** rewriting the script as PowerShell.

Why this path:

- Matches Claude Code’s documented Windows options (Git Bash **or** PowerShell).
- Zero dual-maintenance of business logic.
- Same behavior as macOS/Linux for git shortstat, context math, and colors.

Windows hardening already in `statusline.sh`:

- [x] Strip `\r` from Windows `jq` / git output (CRLF breaks `is_uint` and model `case` matches)
- [x] Normalize `C:\path` → `C:/path` for basename + `git -C` under Git Bash
- [x] README Windows install checklist (EN + 中文)

User checklist:

1. Install Git for Windows  
2. Install `jq` (e.g. `winget` / `scoop` / `choco`) so Git Bash finds it  
3. Install Windows Terminal + Nerd Font  
4. Copy script; `chmod +x` under Git Bash  
5. settings: `"command": "~/.claude/statusline.sh"` (avoid unquoted `\` in paths)  
6. For 500k third-party models, set env in `%USERPROFILE%\.claude\settings.json`

### Alternative paths (later, only if demand is real)

| Route | When | Cost |
|-------|------|------|
| **PowerShell `statusline.ps1`** | Users without Git Bash / corporate lock-down | Full port; dual maintain with bash |
| **Node/TS (ccstatusline-style)** | Product grows into a widget platform | Leaves “zero runtime” niche |
| **WSL-only docs** | Users already develop in WSL | Script unchanged; doesn’t cover native Win Claude Code |

**Decision rule:** do **not** start a PS1 port until Git Bash path is documented, tested once on a real Windows machine, and someone still cannot use it. Prefer issues/PRs over speculative dual scripts.

### Explicit non-goals (Windows)

- Shipping a second default implementation “just in case”
- Emulating every ccstatusline widget on Windows
- Supporting legacy `cmd.exe` as a first-class host without Git Bash

## Mid term

- [ ] Configurable segment order / hide list via env (still no config file required)
- [ ] Optional session line totals as a **separate** labeled segment (never next to `` as fake git dirty)
- [ ] Theme presets beyond Gruvbox (env-selected palettes)
- [ ] Upstream Claude Code schema drift checklist when new `statusLine` fields ship

## Long term / maybe never

- Multi-line layout (tried; rejected for reliability and density)
- Cost / rate-limit / token breakdown by default (noise for third-party APIs)
- Heavy TUI configurator (out of scope; use ccstatusline if you need that)

## Contributing

- Prefer small PRs that preserve Bash 3.2 compatibility and single-line density.
- For Windows: a tested Git Bash report (OS build, Git version, jq version, screenshot) is more valuable than an untested PS1 draft.
- Open an issue before large refactors (Node rewrite, multi-file framework, etc.).

## See also

- [Claude Code status line docs](https://code.claude.com/docs/en/statusline)
- [Environment variables](https://code.claude.com/docs/en/env-vars) (`CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`)
