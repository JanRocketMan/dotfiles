#!/usr/bin/env bash
# Claude Code status line: model, effort, project, VCS branch, context bar

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Read effort level from settings.json
settings_file="$HOME/.claude/settings.json"
effort=""
if [ -f "$settings_file" ]; then
  effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi

# Map effort to symbol
case "$effort" in
  low)    effort_label=" [○ low]" ;;
  medium) effort_label=" [◐ med]" ;;
  high)   effort_label=" [● high]" ;;
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
    # Get jj bookmarks pointing at the working copy
    bookmark=$(jj log -R "$cwd" -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)
    dirty=""
    if [ -n "$(jj diff -R "$cwd" --summary 2>/dev/null)" ]; then
      dirty="*"
    fi
    if [ -n "$bookmark" ]; then
      vcs_info="(${bookmark}${dirty})"
    else
      # Show short change id if no bookmark
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

# Build project segment: " │ my-project git:(main*)"
project_segment=""
if [ -n "$project" ]; then
  project_segment=" │ ${project}"
  if [ -n "$vcs_info" ]; then
    project_segment="${project_segment} ${vcs_info}"
  fi
fi

if [ -z "$used" ]; then
  printf "%s%s%s" "$model" "$effort_label" "$project_segment"
  exit 0
fi

# Round to integer
used_int=$(printf "%.0f" "$used")

# Build a 20-char progress bar
bar_width=20
filled=$(( used_int * bar_width / 100 ))
empty=$(( bar_width - filled ))

bar=""
for i in $(seq 1 $filled); do bar="${bar}█"; done
for i in $(seq 1 $empty);  do bar="${bar}░"; done

# Color the bar: green <50%, yellow 50-79%, red >=80%
if [ "$used_int" -ge 80 ]; then
  color="\033[31m"   # red
elif [ "$used_int" -ge 50 ]; then
  color="\033[33m"   # yellow
else
  color="\033[32m"   # green
fi
reset="\033[0m"

printf "%s%s%s  %b%s%b %d%%" "$model" "$effort_label" "$project_segment" "$color" "$bar" "$reset" "$used_int"
