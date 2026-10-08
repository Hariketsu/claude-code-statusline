#!/usr/bin/env bash
# Smoke tests for statusline.sh — run: bash tests/run.sh
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SL="$ROOT/statusline.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# Run statusline with JSON on stdin, strip ANSI colors
render() {
  printf '%s' "$1" | "$BASH" "$SL" | sed $'s/\033\\[[0-9;]*m//g'
}

expect_has() {
  local name="$1" out="$2" want="$3"
  case "$out" in
    *"$want"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$name" "$want" "$out" ;;
  esac
}

expect_not() {
  local name="$1" out="$2" bad="$3"
  case "$out" in
    *"$bad"*) fail=$((fail + 1)); printf 'FAIL %s\n  unexpected: %s\n  got: %s\n' "$name" "$bad" "$out" ;;
    *) pass=$((pass + 1)) ;;
  esac
}

new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.name t
  git -C "$d" config user.email t@t
  printf '%s' "$d"
}

# --- staged + unstaged edits of the same line count once (vs HEAD) ---
R=$(new_repo same-line)
echo a > "$R/f"; git -C "$R" add f; git -C "$R" commit -qm init
echo b > "$R/f"; git -C "$R" add f; echo c > "$R/f"
out=$(render '{"workspace":{"current_dir":"'"$R"'"}}')
expect_has "same-line diff counted once" "$out" "+1 −1"

# --- staged-only and unstaged-only changes both show ---
R=$(new_repo mixed)
printf '1\n2\n' > "$R/a"; printf 'x\n' > "$R/b"; git -C "$R" add .; git -C "$R" commit -qm init
printf '1\n2\n3\n' > "$R/a"; git -C "$R" add a
printf '' > "$R/b"
out=$(render '{"workspace":{"current_dir":"'"$R"'"}}')
expect_has "staged + unstaged summed" "$out" "+1 −1"

# --- repo without commits: staged lines still counted ---
R=$(new_repo initial)
printf '1\n2\n' > "$R/a"; git -C "$R" add a
out=$(render '{"workspace":{"current_dir":"'"$R"'"}}')
expect_has "initial repo branch" "$out" "main"
expect_has "initial repo staged lines" "$out" "+2"

# --- detached HEAD shows short sha ---
R=$(new_repo detached)
echo a > "$R/f"; git -C "$R" add f; git -C "$R" commit -qm init
sha=$(git -C "$R" rev-parse --short HEAD)
git -C "$R" checkout -q --detach
out=$(render '{"workspace":{"current_dir":"'"$R"'"}}')
expect_has "detached sha" "$out" "$sha"

# --- not a git repo: no git segment, bar still renders ---
mkdir -p "$TMP/plain"
out=$(render '{"workspace":{"current_dir":"'"$TMP/plain"'"}}')
expect_has "non-repo dir" "$out" "plain"
expect_not "non-repo no branch" "$out" "$(printf '\357\220\230')"

# --- used_percentage under comma-decimal locale ---
out=$(printf '%s' '{"context_window":{"used_percentage":12.5}}' | LC_ALL=de_DE.UTF-8 LC_NUMERIC=de_DE.UTF-8 "$BASH" "$SL" | sed $'s/\033\\[[0-9;]*m//g')
expect_has "pct under de_DE locale" "$out" "13%"

# --- missing duration hides time segment; explicit 0 shows 0m ---
out=$(render '{"model":{"display_name":"M"}}')
expect_not "no duration → no 0m" "$out" "0m"
out=$(render '{"model":{"display_name":"M"},"cost":{"total_duration_ms":0}}')
expect_has "explicit 0 duration" "$out" "0m"

# --- empty stdin ---
out=$(render '')
expect_has "empty input" "$out" "no data"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
