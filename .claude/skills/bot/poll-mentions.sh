#!/usr/bin/env bash
# Poll a GitLab project for @<botname> mentions in comments.
# Emits one line per new mention for the Monitor tool.
# On startup, primes seen-set with current events to avoid old mentions.
# Usage: poll-mentions.sh <project> <botname> [poll-interval]

set -euo pipefail

PROJECT="$1"
BOTNAME="$2"
INTERVAL="${3:-10}"

ENCODED=$(echo "$PROJECT" | sed 's|/|%2F|g')
YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d)

# File-based seen set (associative arrays don't survive subshells)
SEEN_FILE=$(mktemp /tmp/bot-seen-XXXXXX)
trap 'rm -f "$SEEN_FILE"' EXIT

# Priming pass: record all current event IDs without emitting
PRIME=$(glab api "projects/$ENCODED/events?action=commented&after=$YESTERDAY&per_page=20" 2>/dev/null || true)
if [ -n "$PRIME" ] && [ "$PRIME" != "[]" ]; then
    echo "$PRIME" | jq -r '.[].id' 2>/dev/null >> "$SEEN_FILE"
fi

is_seen() {
    grep -qx "$1" "$SEEN_FILE" 2>/dev/null
}

mark_seen() {
    echo "$1" >> "$SEEN_FILE"
}

while true; do
    sleep "$INTERVAL"

    EVENTS=$(glab api "projects/$ENCODED/events?action=commented&after=$YESTERDAY&per_page=20" 2>/dev/null || true)

    if [ -n "$EVENTS" ] && [ "$EVENTS" != "[]" ]; then
        # Extract matching events as compact JSON (one per line)
        # noteable_type and noteable_iid are inside .note, not at top level
        MATCHES=$(echo "$EVENTS" | jq -c --arg bot "$BOTNAME" '
            .[] | select(
                .note.body != null and
                (.note.body | contains("@" + $bot)) and
                (.note.body | startswith("[" + $bot + "]") | not)
            ) | {
                id: .id,
                type: (if .note.noteable_type == "MergeRequest" then "mr" else "issue" end),
                iid: (.note.noteable_iid // 0),
                body: (.note.body | split("\n") | first)
            }
        ' 2>/dev/null || true)

        if [ -n "$MATCHES" ]; then
            while IFS= read -r obj; do
                eid=$(echo "$obj" | jq -r '.id')
                is_seen "$eid" && continue
                mark_seen "$eid"

                etype=$(echo "$obj" | jq -r '.type')
                eiid=$(echo "$obj" | jq -r '.iid')
                ebody=$(echo "$obj" | jq -r '.body')

                echo "[$etype:$eiid] $ebody"
            done <<< "$MATCHES"
        fi
    fi

    # Roll over date at midnight
    YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d)
done
