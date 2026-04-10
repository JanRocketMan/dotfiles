#!/usr/bin/env bash
# Stop hook: post Claude's last response to a GitLab issue.
# No-op if GITLAB_REMOTE_PROJECT and GITLAB_REMOTE_ISSUE are not set.

set -euo pipefail

[ -z "${GITLAB_REMOTE_PROJECT:-}" ] && exit 0
[ -z "${GITLAB_REMOTE_ISSUE:-}" ] && exit 0

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

[ -z "$MESSAGE" ] && exit 0

# Truncate to ~60k chars (GitLab note limit is 1MB but keep it reasonable)
MESSAGE="${MESSAGE:0:60000}"

glab issue note "$GITLAB_REMOTE_ISSUE" -R "$GITLAB_REMOTE_PROJECT" -m "[agent] $MESSAGE" 2>/dev/null || true

echo '{"continue":true}'
