#!/usr/bin/env bash
# Poll a GitLab project for new issues, emitting each as a stdout line.
# Designed for use with Claude Code's Monitor tool (persistent mode).
# On startup, records the latest issue IID as baseline. Only emits issues
# created after that point. Exits after emitting the first new issue.
# Usage: poll-issues.sh <project> [poll-interval]

set -euo pipefail

PROJECT="$1"
INTERVAL="${2:-30}"

ENCODED=$(echo "$PROJECT" | sed 's|/|%2F|g')

# Get the current latest issue IID as baseline
BASELINE=$(glab api "projects/$ENCODED/issues?sort=desc&per_page=1&order_by=created_at&state=opened" 2>/dev/null \
    | jq '[.[].iid] | max // 0') || BASELINE=0

while true; do
    sleep "$INTERVAL"

    RESPONSE=$(glab api "projects/$ENCODED/issues?sort=desc&per_page=5&order_by=created_at&state=opened" 2>/dev/null || true)

    if [ -n "$RESPONSE" ]; then
        NEW_ISSUE=$(echo "$RESPONSE" \
            | jq -r --argjson baseline "$BASELINE" \
              '[.[] | select(.iid > $baseline)] | sort_by(.iid) | first | "[\(.iid)] \(.title)\n\(.description // "")"' 2>/dev/null)

        if [ -n "$NEW_ISSUE" ] && [ "$NEW_ISSUE" != "null" ]; then
            echo -e "$NEW_ISSUE"
            exit 0
        fi
    fi
done
