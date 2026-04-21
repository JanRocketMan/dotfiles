---
name: remote
description: Listen for new GitLab issues on the remote project and start working when one is created. Use to put the agent in standby mode awaiting remote instructions.
user-invocable: true
allowed-tools: "Bash(glab *) Bash(echo *) Monitor Read Write(/tmp/remote-session.json)"
---

# Remote Listener

Wait for a new issue to be created on the remote GitLab project, then pick it up and start working.

## How it works

1. Agent starts a Monitor that watches for new issues on `GITLAB_REMOTE_PROJECT`.
2. Agent does nothing — zero tokens consumed while waiting.
3. User creates an issue from phone/browser with a title (the task) and optional description (context).
4. Monitor fires, agent reads the issue, sets up bidirectional comms, and starts working.

## Prerequisites

- `glab` CLI must be installed and authenticated. Run `glab auth status` to verify. If not installed or not logged in, tell the user and stop.
- `GITLAB_REMOTE_PROJECT` environment variable must be set — the GitLab project path (e.g., `user/project`). Verify with `echo $GITLAB_REMOTE_PROJECT`. If empty, tell the user and stop.

## Phase 1: Listen for new issues

Start the issue watcher using the Monitor tool. This is **not** persistent — it exits after the first new issue:

    bash ~/.claude/skills/remote/poll-issues.sh "$GITLAB_REMOTE_PROJECT"

Use `timeout_ms: 3600000` (1 hour). The script polls every 30s.

When the Monitor fires, the notification contains: `[issue-iid] title` followed by the description.

If the Monitor times out with no new issue, restart it.

## Phase 2: Set up bidirectional comms

Once a new issue is detected:

1. Parse the issue IID and title from the notification.
2. Fetch the full issue details if needed:

       glab issue view <iid> -R "$GITLAB_REMOTE_PROJECT"

3. Write the session file so the Stop hook knows where to post:

   Write `/tmp/remote-session.json` with:
   ```json
   {"project": "<GITLAB_REMOTE_PROJECT value>", "issue": "<iid>"}
   ```

4. Post an opening `[agent]` comment acknowledging the task.

5. Start the comment monitor using the Monitor tool with `persistent: true`:

       bash ~/.claude/skills/remote/poll-comments.sh "$GITLAB_REMOTE_PROJECT" <iid> 0

   This polls every 30s. When the user comments, you receive a notification. No tokens consumed while waiting.

## Phase 3: Work on the task

Read the issue title and description as your instructions. Start working on the task. The communication channel is now fully set up:

- **Outbound:** The Stop hook posts your responses automatically.
- **Inbound:** The comment Monitor delivers user messages as notifications.

When you receive a comment notification, read and act on the instructions.

## Closing

When the session is done:

1. Stop the comment monitor using TaskStop.
2. Remove the session file:

       rm /tmp/remote-session.json

3. Close the issue:

       glab issue close <iid> -R "$GITLAB_REMOTE_PROJECT"
