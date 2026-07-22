#!/usr/bin/env bash
# Claude Code Statusline — Starship-inspired single-line status bar
# Reads status JSON from stdin, outputs a colored single line to stdout.
# Dependencies: bash, jq, git (optional)

set -uo pipefail

# ============================================================================
# Model display toggle
# Set to 0 for plain text: DS v4 pro instead of 🐋 v4 pro
# ============================================================================
USE_EMOJI_MODEL="${USE_EMOJI_MODEL:-1}"

# ============================================================================
# Gruvbox dark palette (from Starship config)
# Literal ESC so final printf '%s' still renders colors.
# ============================================================================
C_RST=$'\033[0m'
C_DIM=$'\033[2m'
C_YELLOW=$'\033[38;2;215;153;33m'
C_AQUA=$'\033[38;2;104;157;106m'
C_BLUE=$'\033[38;2;69;133;136m'
C_PURPLE=$'\033[38;2;177;98;134m'
C_GREEN=$'\033[38;2;152;151;26m'
C_RED=$'\033[38;2;204;36;29m'

# --- Helpers ---
dim()   { printf '%s' "${C_DIM}$1${C_RST}"; }
yellow(){ printf '%s' "${C_YELLOW}$1${C_RST}"; }
aqua()  { printf '%s' "${C_AQUA}$1${C_RST}"; }
blue()  { printf '%s' "${C_BLUE}$1${C_RST}"; }
purple(){ printf '%s' "${C_PURPLE}$1${C_RST}"; }
green() { printf '%s' "${C_GREEN}$1${C_RST}"; }
red()   { printf '%s' "${C_RED}$1${C_RST}"; }

# Non-negative integer? (digits only; empty/null → false)
is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Format token count as e.g. 432k (rounded to nearest thousand)
fmt_k() {
  local n="${1:-0}"
  if ! is_uint "$n"; then
    printf '%s' '?'
    return
  fi
  printf '%sk' "$(( (n + 500) / 1000 ))"
}

# Parse git --shortstat text → "INS DEL" (missing side counts as 0)
parse_shortstat() {
  local stat="${1:-}"
  local ins=0 del=0 n
  n=$(printf '%s' "$stat" | sed -n 's/.* \([0-9][0-9]*\) insertion.*/\1/p' 2>/dev/null || true)
  is_uint "$n" && ins="$n"
  n=$(printf '%s' "$stat" | sed -n 's/.* \([0-9][0-9]*\) deletion.*/\1/p' 2>/dev/null || true)
  is_uint "$n" && del="$n"
  printf '%s %s' "$ins" "$del"
}

# --- Read JSON from stdin ---
JSON=$(cat 2>/dev/null || true)
if [ -z "$JSON" ]; then
  printf '%s\n' "$(dim 'no data')"
  exit 0
fi

# --- Extract fields (single jq pass for speed) ---
extract() {
  printf '%s\n' "$JSON" | jq -r '
    (.model.display_name // "?"),
    (.model.id // ""),
    (.workspace.current_dir // ""),
    ((.context_window.context_window_size // "null") | tostring),
    ((.context_window.current_usage.input_tokens // "null") | tostring),
    ((.context_window.current_usage.cache_creation_input_tokens // "null") | tostring),
    ((.context_window.current_usage.cache_read_input_tokens // "null") | tostring),
    (
      if (.context_window.used_percentage | type) == "number"
      then (.context_window.used_percentage | tostring)
      else "null"
      end
    ),
    ((.cost.total_duration_ms // 0) | tostring),
    (
      if (.effort.level | type) == "string" and (.effort.level | length) > 0
      then .effort.level
      else "null"
      end
    )
  ' 2>/dev/null || printf '%s\n' '?' '' '' 'null' 'null' 'null' 'null' 'null' '0' 'null'
}

{
  read -r model_name
  read -r model_id
  read -r current_dir
  read -r ctx_size
  read -r input_tokens
  read -r cache_create
  read -r cache_read
  read -r ctx_pct_raw
  read -r total_duration_ms
  read -r effort_level
} < <(extract)

# ============================================================================
# Model short name (no brackets; no middle-dot separators)
# ============================================================================
model_short=""
case "$model_id" in
  *v4-pro*|*v4_pro*)
    if [ "$USE_EMOJI_MODEL" = "1" ]; then
      model_short="🐋 v4 pro"
    else
      model_short="DS v4 pro"
    fi
    ;;
  *v4-flash*|*v4_flash*)
    if [ "$USE_EMOJI_MODEL" = "1" ]; then
      model_short="🐋 v4 flash"
    else
      model_short="DS v4 flash"
    fi
    ;;
  *grok-4.5*|*grok_4.5*|*grok-4-5*)
    if [ "$USE_EMOJI_MODEL" = "1" ]; then
      model_short="𝕏 4.5"
    else
      model_short="Grok 4.5"
    fi
    ;;
  *)
    if [ -n "$model_name" ] && [ "$model_name" != "?" ] && [ "$model_name" != "null" ]; then
      model_short="$model_name"
    elif [ -n "$model_id" ] && [ "$model_id" != "null" ]; then
      model_short="$model_id"
    else
      model_short="?"
    fi
    ;;
esac

# ============================================================================
# Build segments
# Layout: model · effort · dir · git[+diff] · ctx · time
# ============================================================================
DSEP="$(dim '·')"   # dimmed separator
MINUS='−'            # Unicode minus sign U+2212 (not hyphen-minus)

# Nerd Font icons (PUA; bash \u is only 4 hex digits → use octal UTF-8)
# U+F09D1 effort / brain
EFFORT_ICON=$(printf '\363\260\247\221')
# U+F418 nf-oct-git-branch
GIT_ICON=$(printf '\357\220\230')
# U+F0873 / U+F0875 / U+F029A / U+F0874 context gauge
CTX_ICON_EMPTY=$(printf '\363\260\241\263')
CTX_ICON_LOW=$(printf '\363\260\241\265')
CTX_ICON_MID=$(printf '\363\260\212\232')
CTX_ICON_FULL=$(printf '\363\260\241\264')

# 1. Model (blue, no brackets)
seg_model="$(blue "$model_short")"

# 1b. Effort level (after model; hide if unsupported / missing)
# API: low | medium | high | xhigh | max
seg_effort=""
case "${effort_level:-}" in
  low)     seg_effort=$(dim "${EFFORT_ICON} low") ;;
  medium)  seg_effort=$(dim "${EFFORT_ICON} med") ;;
  high)    seg_effort=$(dim "${EFFORT_ICON} high") ;;
  xhigh)   seg_effort=$(dim "${EFFORT_ICON} xhigh") ;;
  max)     seg_effort=$(dim "${EFFORT_ICON} max") ;;
esac

# 2. Directory basename
dir_base=$(basename "${current_dir:-}" 2>/dev/null || true)
[ -z "$dir_base" ] && dir_base="?"
seg_dir="$(aqua "$dir_base")"

# 3–4. Git branch + real working-tree diff lines
# Branch/detached: git -C only; failures hide just this segment.
# Lines: unstaged + staged shortstat (not Claude cost.total_lines_*).
#   git diff --shortstat
#   git diff --cached --shortstat
seg_git=""
seg_lines=""
if [ -n "${current_dir:-}" ]; then
  if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || true)
    if [ -n "$branch" ]; then
      seg_git="$(purple "${GIT_ICON} $branch")"
    else
      short_sha=$(git -C "$current_dir" rev-parse --short HEAD 2>/dev/null || true)
      if [ -n "$short_sha" ]; then
        seg_git="$(purple "${GIT_ICON} $short_sha")"
      fi
    fi

    lines_added=0
    lines_removed=0
    unstaged_stat=$(GIT_OPTIONAL_LOCKS=1 git -C "$current_dir" diff --shortstat 2>/dev/null || true)
    staged_stat=$(GIT_OPTIONAL_LOCKS=1 git -C "$current_dir" diff --cached --shortstat 2>/dev/null || true)

    read -r u_add u_del <<EOF
$(parse_shortstat "$unstaged_stat")
EOF
    read -r s_add s_del <<EOF
$(parse_shortstat "$staged_stat")
EOF
    is_uint "${u_add:-}" || u_add=0
    is_uint "${u_del:-}" || u_del=0
    is_uint "${s_add:-}" || s_add=0
    is_uint "${s_del:-}" || s_del=0
    lines_added=$(( u_add + s_add ))
    lines_removed=$(( u_del + s_del ))

    if [ "$lines_added" -gt 0 ]; then
      seg_lines+=$(green "+${lines_added}")
    fi
    if [ "$lines_removed" -gt 0 ]; then
      [ -n "$seg_lines" ] && seg_lines+=" "
      seg_lines+=$(red "${MINUS}${lines_removed}")
    fi
  fi
fi

# Merge git + lines into one segment (space, no ·)
seg_git_lines=""
if [ -n "$seg_git" ] && [ -n "$seg_lines" ]; then
  seg_git_lines="$seg_git $seg_lines"
elif [ -n "$seg_git" ]; then
  seg_git_lines="$seg_git"
fi

# 5. Context usage
# Limit priority: context_window_size → $CLAUDE_CODE_MAX_CONTEXT_TOKENS → 200000
# Used: input + cache_creation + cache_read; fallback to used_percentage.
# Display: Nerd Font gauge icon + pct%/limit  (e.g. 󰡵 15%/500k)
# Icon tiers follow visual fill (not warn color):
#   f0873 empty  :  0 ≤ p < 30
#   f0875 low    : 30 ≤ p < 55
#   f029a mid    : 55 ≤ p < 85
#   f0874 full   : p ≥ 85  (includes >100%)
# Color by remaining tokens (independent of icon):
#   danger  < max(limit*8%,  15000) → red
#   warning < max(limit*15%, 30000) → yellow
#   else                            → dim
seg_ctx=""
context_limit=""
if is_uint "${ctx_size:-}" && [ "$ctx_size" -gt 0 ]; then
  context_limit="$ctx_size"
elif is_uint "${CLAUDE_CODE_MAX_CONTEXT_TOKENS:-}" && [ "${CLAUDE_CODE_MAX_CONTEXT_TOKENS}" -gt 0 ]; then
  context_limit="$CLAUDE_CODE_MAX_CONTEXT_TOKENS"
else
  context_limit=200000
fi

used=""
# input_tokens required; missing cache fields count as 0
if is_uint "${input_tokens:-}"; then
  cache_create_value=0
  cache_read_value=0
  is_uint "${cache_create:-}" && cache_create_value="$cache_create"
  is_uint "${cache_read:-}" && cache_read_value="$cache_read"
  used=$(( input_tokens + cache_create_value + cache_read_value ))
fi

pct_int=""
if [ -n "$used" ] && [ "$context_limit" -gt 0 ]; then
  # Rounded integer percent; may exceed 100
  pct_int=$(( (used * 100 + context_limit / 2) / context_limit ))
elif [ -n "${ctx_pct_raw:-}" ] && [ "$ctx_pct_raw" != "null" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct_raw" 2>/dev/null) || pct_int=""
  if ! is_uint "$pct_int"; then
    pct_int=""
  fi
  # Estimate used from percentage when token breakdown is missing
  if [ -n "$pct_int" ] && [ -z "$used" ] && [ "$context_limit" -gt 0 ]; then
    used=$(( (context_limit * pct_int + 50) / 100 ))
  fi
fi

# Gauge icon from percentage (visual fill), independent of color thresholds
ctx_icon_for_pct() {
  local p="$1"
  if ! is_uint "$p"; then
    printf '%s' "$CTX_ICON_EMPTY"
    return
  fi
  if [ "$p" -lt 30 ]; then
    printf '%s' "$CTX_ICON_EMPTY"
  elif [ "$p" -lt 55 ]; then
    printf '%s' "$CTX_ICON_LOW"
  elif [ "$p" -lt 85 ]; then
    printf '%s' "$CTX_ICON_MID"
  else
    printf '%s' "$CTX_ICON_FULL"
  fi
}

if [ -n "$used" ] && [ -n "$pct_int" ] && [ "$context_limit" -gt 0 ]; then
  remaining=$(( context_limit - used ))
  [ "$remaining" -lt 0 ] && remaining=0

  warn_thr=$(( context_limit * 15 / 100 ))
  [ "$warn_thr" -lt 30000 ] && warn_thr=30000
  danger_thr=$(( context_limit * 8 / 100 ))
  [ "$danger_thr" -lt 15000 ] && danger_thr=15000

  ctx_icon=$(ctx_icon_for_pct "$pct_int")
  ctx_label="${ctx_icon} ${pct_int}%/$(fmt_k "$context_limit")"
  if [ "$remaining" -lt "$danger_thr" ]; then
    seg_ctx=$(red "$ctx_label")
  elif [ "$remaining" -lt "$warn_thr" ]; then
    seg_ctx=$(yellow "$ctx_label")
  else
    seg_ctx=$(dim "$ctx_label")
  fi
elif [ -n "$pct_int" ]; then
  # Percentage only (no usable limit) — still show gauge + pct
  ctx_icon=$(ctx_icon_for_pct "$pct_int")
  seg_ctx=$(dim "${ctx_icon} ${pct_int}%")
else
  seg_ctx=$(dim "$(printf '%s --' "$CTX_ICON_EMPTY")")
fi

# 6. Session duration — from Claude Code's built-in cost.total_duration_ms
seg_time=""
if is_uint "${total_duration_ms:-}" && [ "$total_duration_ms" -gt 0 ]; then
  total_sec=$(( total_duration_ms / 1000 ))
  if [ "$total_sec" -ge 3600 ]; then
    hours=$(( total_sec / 3600 ))
    mins=$(( (total_sec % 3600) / 60 ))
    seg_time=$(dim "${hours}h${mins}m")
  else
    mins=$(( total_sec / 60 ))
    seg_time=$(dim "${mins}m")
  fi
elif [ "${total_duration_ms:-}" = "0" ]; then
  seg_time=$(dim '0m')
fi

# ============================================================================
# Assemble single line
# model · effort · dir ·  branch +N −M · 󰡵 15%/500k · 42m
# ============================================================================
out="$seg_model"
[ -n "$seg_effort" ]    && out+=" $DSEP $seg_effort"
out+=" $DSEP $seg_dir"
[ -n "$seg_git_lines" ] && out+=" $DSEP $seg_git_lines"
out+=" $DSEP $seg_ctx"
[ -n "$seg_time" ]      && out+=" $DSEP $seg_time"

printf '%s\n' "$out"
