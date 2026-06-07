# Claude Code Statusline

A custom [Claude Code](https://code.claude.com/docs/en/statusline) status bar script designed for **DeepSeek API** users. Displays session context in a clean single line with Gruvbox Dark colors matching the [Starship](https://starship.rs) prompt.

```
[🐋 v4·pro]  my-project · main · +261 −1 · 55% context · 42m
```

## What It Shows

| Segment | Example | Source Field |
|---------|---------|-------------|
| Model | `[🐋 v4·pro]` | `.model.id` mapped to short name |
| Directory | `my-project` | `.workspace.current_dir` basename |
| Git branch | `dev` | `git branch --show-current` (repo only) |
| Lines changed | `+261 −1` | `.cost.total_lines_added` / `total_lines_removed` |
| Context usage | `55% context` | `.context_window.used_percentage` |
| Session duration | `42m` | `.cost.total_duration_ms` |

Context color thresholds follow the [official Claude Code example](https://code.claude.com/docs/en/statusline#display-multiple-lines):

- **< 70%** — dim (safe)
- **70–89%** — yellow (warning)
- **90%+** — red (danger)

## What It Does NOT Show

This script is built for third-party Anthropic-compatible APIs (DeepSeek). It deliberately omits:

- **Token usage** (`i:`, `o:`, `cw:`, `cr:`) — adds noise without actionable value
- **Cost estimates** (`cc_est`, `ds_est`) — client-side estimates don't match actual DeepSeek billing
- **Rate limits** — available only to Claude.ai Pro/Max subscribers
- **Progress bars** — keeps the line compact and scannable

## Prerequisites

- [Claude Code](https://code.claude.com/docs/en/overview) v2.1.132+
- [`jq`](https://jqlang.github.io/jq/) — JSON parsing
- `git` — branch detection (optional; gracefully degrades)

```sh
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq
```

## Setup

**1. Install the script:**

```sh
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

**2. Add to `~/.claude/settings.json`:**

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0,
    "refreshInterval": 30
  }
}
```

| Setting | Purpose |
|---------|---------|
| `padding` | Extra horizontal spacing. Set to `0` to minimize indentation. |
| `refreshInterval` | Re-runs the script every N seconds. Needed because session duration changes over time. 30s is a reasonable default; adjust to taste. |

## Customization

### Model display

Set `USE_EMOJI_MODEL=0` for plain text labels:

```json
{
  "statusLine": {
    "type": "command",
    "command": "USE_EMOJI_MODEL=0 ~/.claude/statusline.sh"
  }
}
```

Output: `[DS v4·pro]` instead of `[🐋 v4·pro]`

### Add new DeepSeek models

Edit the `case` block near line 70 in the script. The matching is against `.model.id`:

```bash
case "$model_id" in
  *v4-pro*)   model_short="🐋 v4·pro"   ;;
  *v4-flash*) model_short="🐋 v4·flash" ;;
  *r1*)       model_short="🐋 r1"       ;;  # add yours here
  *)          model_short="$model_name"  ;;
esac
```

### Colors

The palette is [Gruvbox Dark](https://github.com/morhetz/gruvbox), chosen to match the author's Starship prompt. Edit the `C_*` variables at the top of the script to use any ANSI true-color values.

## Available Fields

The script receives a JSON object from Claude Code on stdin. Key fields used:

| Field | Type | Notes |
|-------|------|-------|
| `model.id` | string | Raw model identifier for short-name mapping |
| `model.display_name` | string | Fallback when `model.id` doesn't match a known pattern |
| `workspace.current_dir` | string | Full path; script shows basename only |
| `cost.total_lines_added` | number | Omitted when 0 |
| `cost.total_lines_removed` | number | Displayed with Unicode minus sign `−` |
| `cost.total_duration_ms` | number | Session wall-clock time in milliseconds |
| `context_window.used_percentage` | number | Pre-calculated by Claude Code |

Full schema: [Claude Code Statusline Docs](https://code.claude.com/docs/en/statusline#available-data)

## Testing

Pipe mock JSON to verify output:

```sh
echo '{
  "model": {"display_name": "DeepSeek V4 Pro", "id": "deepseek-v4-pro[1m]"},
  "workspace": {"current_dir": "/Users/me/projects/my-project"},
  "cost": {"total_lines_added": 261, "total_lines_removed": 1, "total_duration_ms": 2520000},
  "context_window": {"used_percentage": 55.2}
}' | ~/.claude/statusline.sh
```

Expected (ANSI colors stripped): `[🐋 v4·pro]  my-project · main · +261 −1 · 55% context · 42m`

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Status line blank | Script isn't executable. Run `chmod +x ~/.claude/statusline.sh` |
| Duration always `0m` | `refreshInterval` not set. Duration updates only on events without it. |
| `context --` | Normal before first API response. Disappears after the first message. |
| Leading whitespace before model tag | Claude Code built-in spacing plus `padding`. Set `"padding": 0` to minimize. |

## License

MIT
