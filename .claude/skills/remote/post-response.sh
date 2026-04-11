#!/usr/bin/env bash
# Stop hook: post Claude's last response to a GitLab issue.
# No-op if /tmp/remote-session.json doesn't exist.

set -euo pipefail

SESSION_FILE="/tmp/remote-session.json"
[ -f "$SESSION_FILE" ] || exit 0

PROJECT=$(jq -r '.project // empty' "$SESSION_FILE")
ISSUE=$(jq -r '.issue // empty' "$SESSION_FILE")
[ -z "$PROJECT" ] && exit 0
[ -z "$ISSUE" ] && exit 0

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')
[ -z "$MESSAGE" ] && exit 0

# Truncate to ~60k chars (GitLab note limit is 1MB but keep it reasonable)
MESSAGE="${MESSAGE:0:60000}"

glab issue note "$ISSUE" -R "$PROJECT" -m "[agent] $MESSAGE" 2>/dev/null || true

echo '{"continue":true}'
