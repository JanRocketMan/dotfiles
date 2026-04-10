#!/usr/bin/env bash
# Poll a GitLab issue for new non-agent comments, emitting each as a stdout line.
# Designed for use with Claude Code's Monitor tool (persistent mode).
# Usage: poll-comments.sh <project> <issue> <last-seen-id> [poll-interval]

set -euo pipefail

PROJECT="$1"
ISSUE="$2"
LAST_ID="${3:-0}"
INTERVAL="${4:-30}"

ENCODED=$(echo "$PROJECT" | sed 's|/|%2F|g')

while true; do
    RESPONSE=$(glab api "projects/$ENCODED/issues/$ISSUE/notes?sort=asc&per_page=50&order_by=created_at" 2>/dev/null || true)

    if [ -n "$RESPONSE" ]; then
        COMMENTS=$(echo "$RESPONSE" \
            | jq -r --argjson last "$LAST_ID" \
              '.[] | select(.system == false and (.id > $last) and (.body | startswith("[agent]") | not)) | "[\(.id)] \(.body)"')

        if [ -n "$COMMENTS" ]; then
            echo "$COMMENTS"
            NEW_LAST=$(echo "$RESPONSE" \
                | jq --argjson last "$LAST_ID" \
                  '[.[] | select(.system == false and (.id > $last)) | .id] | max')
            if [ "$NEW_LAST" != "null" ] && [ -n "$NEW_LAST" ]; then
                LAST_ID=$NEW_LAST
            fi
        fi
    fi

    sleep "$INTERVAL"
done
