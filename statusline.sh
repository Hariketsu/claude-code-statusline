#!/usr/bin/env bash
# Claude Code Statusline — Starship-inspired single-line status bar
# Reads status JSON from stdin, outputs a colored single line to stdout.
# Dependencies: bash, jq, git (optional)

set -euo pipefail

# ============================================================================
# Model display toggle
# Set to 0 for plain text: [DS v4·pro] instead of [🐋 v4·pro]
# ============================================================================
USE_EMOJI_MODEL="${USE_EMOJI_MODEL:-1}"

# ============================================================================
# Gruvbox dark palette (from Starship config)
# ============================================================================
C_RST="\033[0m"
C_DIM="\033[2m"
C_YELLOW="\033[38;2;215;153;33m"
C_AQUA="\033[38;2;104;157;106m"
C_BLUE="\033[38;2;69;133;136m"
C_PURPLE="\033[38;2;177;98;134m"
C_GREEN="\033[38;2;152;151;26m"
C_RED="\033[38;2;204;36;29m"

# --- Helpers ---
dim()   { printf '%b' "${C_DIM}$1${C_RST}"; }
yellow(){ printf '%b' "${C_YELLOW}$1${C_RST}"; }
aqua()  { printf '%b' "${C_AQUA}$1${C_RST}"; }
blue()  { printf '%b' "${C_BLUE}$1${C_RST}"; }
purple(){ printf '%b' "${C_PURPLE}$1${C_RST}"; }
green() { printf '%b' "${C_GREEN}$1${C_RST}"; }
red()   { printf '%b' "${C_RED}$1${C_RST}"; }

# --- Read JSON from stdin ---
JSON=$(cat 2>/dev/null || true)
if [ -z "$JSON" ]; then
  printf '%b' "$(dim 'no data')"
  exit 0
fi

# --- Extract fields (single jq pass for speed) ---
extract() {
  echo "$JSON" | jq -r '
    (.model.display_name // "?"),
    (.model.id // ""),
    (.workspace.current_dir // ""),
    ((.cost.total_lines_added // 0) | tostring),
    ((.cost.total_lines_removed // 0) | tostring),
    ((.context_window.used_percentage) // "null" | tostring),
    ((.cost.total_duration_ms // 0) | tostring)
  ' 2>/dev/null || printf '?\n\n\n0\n0\nnull\n0'
}

{
  read -r model_name
  read -r model_id
  read -r current_dir
  read -r lines_added
  read -r lines_removed
  read -r ctx_pct_raw
  read -r total_duration_ms
} < <(extract)

# ============================================================================
# Model short name
# ============================================================================
model_short=""
case "$model_id" in
  *v4-pro*|*v4_pro*)
    if [ "$USE_EMOJI_MODEL" = "1" ]; then
      model_short="🐋 v4·pro"
    else
      model_short="DS v4·pro"
    fi
    ;;
  *v4-flash*|*v4_flash*)
    if [ "$USE_EMOJI_MODEL" = "1" ]; then
      model_short="🐋 v4·flash"
    else
      model_short="DS v4·flash"
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
# ============================================================================
DSEP="$(dim '·')"   # dimmed separator
MINUS='−'            # Unicode minus sign U+2212 (not hyphen-minus)

# 1. Model tag
seg_model="[$(blue "$model_short")]"

# 2. Directory basename
dir_base=$(basename "$current_dir" 2>/dev/null || true)
[ -z "$dir_base" ] && dir_base="?"
seg_dir="$(aqua "$dir_base")"

# 3. Git branch (fast: rev-parse + branch name only, no status scan)
seg_git=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || true)
  if [ -n "$branch" ]; then
    seg_git="$(purple " $branch")"
  fi
fi

# 4. Lines added / removed (omit if both are 0)
seg_lines=""
if [ "$lines_added" != "0" ] && [ "$lines_added" != "null" ]; then
  seg_lines+=$(green "+${lines_added}")
fi
if [ "$lines_removed" != "0" ] && [ "$lines_removed" != "null" ]; then
  [ -n "$seg_lines" ] && seg_lines+=" "
  seg_lines+=$(red "${MINUS}${lines_removed}")
fi

# 5. Context usage
# Thresholds match official Claude Code example: <70% safe, 70-89% warn, 90%+ danger
seg_ctx=""
if [ "$ctx_pct_raw" != "null" ] && [ -n "$ctx_pct_raw" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct_raw" 2>/dev/null || echo "0")
  if [ "$pct_int" -ge 90 ]; then
    seg_ctx=$(red "${pct_int}% context")
  elif [ "$pct_int" -ge 70 ]; then
    seg_ctx=$(yellow "${pct_int}% context")
  else
    seg_ctx=$(dim "${pct_int}% context")
  fi
else
  seg_ctx=$(dim 'context --')
fi

# 6. Session duration — from Claude Code's built-in cost.total_duration_ms
seg_time=""
if [ "$total_duration_ms" != "null" ] && [ "$total_duration_ms" != "0" ] && [ -n "$total_duration_ms" ]; then
  total_sec=$(( total_duration_ms / 1000 ))
  if [ "$total_sec" -ge 3600 ]; then
    hours=$(( total_sec / 3600 ))
    mins=$(( (total_sec % 3600) / 60 ))
    seg_time=$(dim "${hours}h${mins}m")
  else
    mins=$(( total_sec / 60 ))
    seg_time=$(dim "${mins}m")
  fi
elif [ "$total_duration_ms" = "0" ]; then
  seg_time=$(dim '0m')
fi

# ============================================================================
# Assemble single line
# [model]  dir · git · +N −M · XX% context · 42m
#         ^^ two spaces between model tag and directory
# ============================================================================
out="$seg_model  $seg_dir"
[ -n "$seg_git" ]   && out+=" $DSEP $seg_git"
[ -n "$seg_lines" ] && out+=" $DSEP $seg_lines"
out+=" $DSEP $seg_ctx"
[ -n "$seg_time" ]  && out+=" $DSEP $seg_time"

printf '%b' "$out"
