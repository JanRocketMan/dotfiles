#!/usr/bin/env bash
# Stop hook: post Claude's last response to a GitLab issue or MR.
# Finds the session file matching the current session_id.
# Supports both legacy /remote files and /bot files.
# No-op if no matching session file exists.

set -euo pipefail

# Read stdin first (consumed once)
INPUT=$(cat)
HOOK_SESSION=$(echo "$INPUT" | jq -r '.session_id // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[ -z "$MESSAGE" ] && exit 0

# Truncate to ~60k chars
MESSAGE="${MESSAGE:0:60000}"

# Find matching session file
SESSION_FILE=""
for f in /tmp/remote-session*.json; do
    [ -f "$f" ] || continue
    FILE_SESSION=$(jq -r '.session_id // empty' "$f" 2>/dev/null)
    if [ -n "$HOOK_SESSION" ] && [ "$FILE_SESSION" = "$HOOK_SESSION" ]; then
        SESSION_FILE="$f"
        break
    elif [ -z "$FILE_SESSION" ] && [ "$f" = "/tmp/remote-session.json" ]; then
        # Legacy fallback: old-format file without session_id
        SESSION_FILE="$f"
        break
    fi
done

[ -z "$SESSION_FILE" ] && exit 0

PROJECT=$(jq -r '.project // empty' "$SESSION_FILE")
[ -z "$PROJECT" ] && exit 0

TYPE=$(jq -r '.type // "issue"' "$SESSION_FILE")
IID=$(jq -r '.iid // .issue // empty' "$SESSION_FILE")
PREFIX=$(jq -r '.prefix // "[agent]"' "$SESSION_FILE")
[ -z "$IID" ] && exit 0

ENCODED=$(echo "$PROJECT" | sed 's|/|%2F|g')

if [ "$TYPE" = "mr" ]; then
    # Use glab api for MR notes
    BODY="$PREFIX $MESSAGE"
    glab api --method POST "projects/$ENCODED/merge_requests/$IID/notes" \
        -f "body=$BODY" 2>/dev/null || true
else
    glab issue note "$IID" -R "$PROJECT" -m "$PREFIX $MESSAGE" 2>/dev/null || true
fi

echo '{"continue":true}'
