---
name: remote
description: Open a bidirectional communication channel with the user via a GitLab issue. Creates a new issue per session for sending updates and receiving instructions remotely.
argument-hint: "[session description]"
user-invocable: true
allowed-tools: "Bash(glab *) Bash(echo *) Monitor Read Write(/tmp/remote-session.json)"
---

# Remote Communication Channel

Open a GitLab issue as a bidirectional communication channel with the user. One issue per session.

## How it works

- **Outbound (you → user):** A global Stop hook automatically posts your last response as a comment on the issue after every turn. You don't need to post comments manually.
- **Inbound (user → you):** A persistent Monitor polls the issue for new comments and delivers them as notifications. You don't need to poll manually.

## Configuration

Requires the `GITLAB_REMOTE_PROJECT` environment variable — the GitLab project path (e.g., `user/project`).

Before doing anything, verify it is set by running `echo $GITLAB_REMOTE_PROJECT`. If empty, tell the user to export it and stop.

## Setup (do this once at the start)

1. Create a new issue for this session. Use `$ARGUMENTS` as the title context, or summarize the current task if arguments are empty:

       glab issue create -R "$GITLAB_REMOTE_PROJECT" --title "<title>" --description "Remote session. Post comments to send instructions." --no-editor

2. Extract the issue number from the output and write the session file so the Stop hook knows where to post:

   Write `/tmp/remote-session.json` with:
   ```json
   {"project": "<GITLAB_REMOTE_PROJECT value>", "issue": "<issue-number>"}
   ```

3. Start the comment monitor using the Monitor tool with `persistent: true`:

       bash ~/.claude/skills/remote/poll-comments.sh "$GITLAB_REMOTE_PROJECT" <issue-number> 0

   This polls every 30s. When the user comments, you receive a notification with `[comment-id] message`. No tokens are consumed while waiting.

That's it. Both directions are now automated.

## Receiving messages

The Monitor delivers notifications directly into the conversation when the user comments. When you receive a notification, read the message and act on the instructions.

## Sending messages

Your responses are posted automatically by the Stop hook — every time you finish a response, it gets posted as a `[agent]` comment on the issue. You do not need to run `glab issue note` yourself.

If you need to send an **extra** message beyond your normal response (e.g., a brief acknowledgement before starting long work), you can still post manually:

    glab issue note <issue-number> -R "$GITLAB_REMOTE_PROJECT" -m "[agent] <message>"

## Closing

When the session is done:

1. Stop the monitor using TaskStop.
2. Remove the session file so the Stop hook deactivates:

       rm /tmp/remote-session.json

3. Close the issue:

       glab issue close <issue-number> -R "$GITLAB_REMOTE_PROJECT"
