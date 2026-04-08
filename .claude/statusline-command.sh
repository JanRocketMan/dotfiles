#!/usr/bin/env bash
# Claude Code status line: model, effort, project, VCS branch, context breakdown

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"' | sed 's/ ([^)]*context)//')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Context window fields
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
# current_usage tokens (null before first API call)
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

# Read effort level from settings.json
settings_file="$HOME/.claude/settings.json"
effort=""
if [ -f "$settings_file" ]; then
  effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi

# Map effort to symbol
case "$effort" in
  low)    effort_label=" [low]" ;;
  medium) effort_label=" [med]" ;;
  high)   effort_label=" [high]" ;;
  *)      effort_label="" ;;
esac

# Project name from cwd
project=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  project=$(basename "$cwd")
fi

# VCS info: prefer jj, fall back to git
vcs_info=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  if command -v jj &>/dev/null && jj root --quiet -R "$cwd" &>/dev/null; then
    bookmark=$(jj log -R "$cwd" -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)
    dirty=""
    if [ -n "$(jj diff -R "$cwd" --summary 2>/dev/null)" ]; then
      dirty="*"
    fi
    if [ -n "$bookmark" ]; then
      vcs_info="(${bookmark}${dirty})"
    else
      change_id=$(jj log -R "$cwd" -r @ --no-graph -T 'change_id.shortest(8)' 2>/dev/null)
      vcs_info="(${change_id:-@}${dirty})"
    fi
  elif command -v git &>/dev/null && git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    dirty=""
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
      dirty="*"
    fi
    if [ -n "$branch" ]; then
      vcs_info="(${branch}${dirty})"
    fi
  fi
fi

# Build project segment
project_segment=""
if [ -n "$project" ]; then
  project_segment=" │ ${project}"
  if [ -n "$vcs_info" ]; then
    project_segment="${project_segment} ${vcs_info}"
  fi
fi

# Format token count with K/M suffix
fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf "%.1fM" "$(echo "$n / 1000000" | bc -l)"
  elif [ "$n" -ge 1000 ]; then
    printf "%.0fk" "$(echo "$n / 1000" | bc -l)"
  else
    printf "%d" "$n"
  fi
}

# Build context segment
ctx_segment=""
if [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  # Total tokens in context = cached (sys/tools/memory) + uncached (messages)
  sys_tokens=$(( cache_create + cache_read ))
  total_used=$(( sys_tokens + input_tokens ))
  used_int=$(printf "%.0f" "${used_pct:-0}")

  # Color: green <50%, yellow 50-79%, red >=80%
  if [ "$used_int" -ge 80 ]; then
    color="\033[31m"
  elif [ "$used_int" -ge 50 ]; then
    color="\033[33m"
  else
    color="\033[32m"
  fi
  reset="\033[0m"

  ctx_segment=" │ ctx ${color}$(fmt_tokens "$total_used")/$(fmt_tokens "$ctx_size")${reset} (${used_int}%)"
fi

printf "%s%s%s%b" "$model" "$effort_label" "$project_segment" "$ctx_segment"
