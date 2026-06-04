#!/usr/bin/env bash
# Claude Code status line, styled after the .pi/agent footer (footer-info.ts):
#   ~/dotfiles on nvim-0.12          usg 08% • 110k on Opus 4.8 [1m] • 04t/s • high
#
# Left/right justified across the terminal width, in the normal foreground color.
# Left = ~cwd + VCS branch; right block (hugging the right edge, joined by " • ")
# = 5-hour usage %, context tokens, model [context-window], per-turn speed, effort.
# Number formats mirror the pi footer's fixed-width formatters.

# Columns to leave free at the right edge. Claude Code renders the status line
# with a small right margin, so filling the full detected width clips the last
# segment. Bump this if the trailing word still truncates; lower it toward 0 if
# there is a visible gap before the right edge.
RIGHT_MARGIN=3

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
# Friendly model name, e.g. "Opus 4.8" (strip any "(1M context)" suffix).
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' | sed 's/ ([^)]*context)//')

ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
usg_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Effort level comes from settings.json.
settings_file="$HOME/.claude/settings.json"
effort=""
[ -f "$settings_file" ] && effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)

# ── left: ~cwd on <branch> ──────────────────────────────────────────────────
home="${HOME%/}"
case "$cwd" in
  "$home")    path_label="~" ;;
  "$home"/*)  path_label="~/${cwd#"$home"/}" ;;
  *)          path_label="$cwd" ;;
esac

branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  if command -v jj &>/dev/null && jj root --quiet -R "$cwd" &>/dev/null; then
    branch=$(jj log -R "$cwd" -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)
    [ -z "$branch" ] && branch=$(jj log -R "$cwd" -r @- --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)
  elif command -v git &>/dev/null && git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  fi
fi

left="$path_label"
[ -n "$branch" ] && left="$path_label on $branch"

# ── right block formatters (mirror footer-info.ts) ──────────────────────────
# usage: 5-hour rolling window %, min 2-digit zero-padded -> usg 08%
if [ -n "$usg_pct" ]; then
  usg_str=$(printf 'usg %02d%%' "$(printf '%.0f' "$usg_pct")")
else
  usg_str="usg --%"
fi

# context: tokens in context, 3-digit zero-padded k, capped at 999k
total_used=$(( cache_create + cache_read + input_tokens ))
if [ "$total_used" -le 0 ]; then
  ctx_str="???k"
else
  k=$(( (total_used + 500) / 1000 ))
  [ "$k" -gt 999 ] && k=999
  ctx_str=$(printf '%03dk' "$k")
fi

# context-window label: [1m] / [200k] / [<n>]
if [ "$ctx_size" -ge 1000000 ] 2>/dev/null; then
  cw="[$(( ctx_size / 1000000 ))m]"
elif [ "$ctx_size" -ge 1000 ] 2>/dev/null; then
  cw="[$(( ctx_size / 1000 ))k]"
elif [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  cw="[$ctx_size]"
else
  cw=""
fi

# model: friendly name + spaced context-window suffix -> "Opus 4.8 [1m]"
model="$model_name"
[ -n "$cw" ] && model="$model_name $cw"

# speed: per-turn output tok/s via delta tracking, 2-digit zero-padded, capped 99
session_id=$(echo "$input" | jq -r '.session_id // empty')
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
tps_str="--t/s"
if [ -n "$session_id" ] && [ "$api_duration_ms" -gt 0 ] 2>/dev/null && [ "$output_tokens" -gt 0 ] 2>/dev/null; then
  state_file="/tmp/claude-statusline-${session_id}"
  prev_tokens=0 prev_duration=0
  [ -f "$state_file" ] && read -r prev_tokens prev_duration < "$state_file" 2>/dev/null || true
  echo "$output_tokens $api_duration_ms" > "$state_file"
  delta_tokens=$(( output_tokens - prev_tokens ))
  delta_ms=$(( api_duration_ms - prev_duration ))
  if [ "$delta_ms" -gt 0 ] && [ "$delta_tokens" -gt 0 ]; then
    tps=$(( delta_tokens * 1000 / delta_ms ))
    [ "$tps" -gt 99 ] && tps=99
    tps_str=$(printf '%02dt/s' "$tps")
  fi
fi

# effort/thinking level (full word, like the pi footer's thinking level)
case "$effort" in
  low)    effort_label="low" ;;
  medium) effort_label="medium" ;;
  high)   effort_label="high" ;;
  *)      effort_label="" ;;
esac

# ── assemble right block and justify it against the terminal width ──────────
right="${usg_str} • ${ctx_str} on ${model} • ${tps_str}"
[ -n "$effort_label" ] && right="${right} • ${effort_label}"

# Width: prefer COLUMNS (Claude Code exports it), else tput, else a default.
width="${COLUMNS:-}"
if ! [ "$width" -gt 0 ] 2>/dev/null; then
  width=$(tput cols 2>/dev/null)
fi
if ! [ "$width" -gt 0 ] 2>/dev/null; then
  width=120
fi

pad=$(( width - RIGHT_MARGIN - ${#left} - ${#right} ))
[ "$pad" -lt 1 ] && pad=1
spaces=$(printf '%*s' "$pad" '')

printf '%s%s%s' "$left" "$spaces" "$right"
