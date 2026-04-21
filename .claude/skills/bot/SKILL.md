---
name: bot
description: "Create a named bot that monitors a GitLab project for @mentions and responds in issues and MRs. Usage: /bot <name>"
argument-hint: "<bot-name>"
user-invocable: true
allowed-tools: "Bash(glab *) Bash(echo *) Monitor Read Write(/tmp/remote-session-*)"
---

# GitLab Bot

Create a named bot entity (e.g., `/bot solver`) that watches a GitLab project for `@<name>` mentions in issue and MR comments, picks them up, works on them, and responds in-place.

## Prerequisites

- `glab` CLI must be installed and authenticated. Run `glab auth status` to verify. If not installed or not logged in, tell the user and stop.
- `GITLAB_REMOTE_PROJECT` environment variable must be set — the GitLab project path (e.g., `group/project`). Verify with `echo $GITLAB_REMOTE_PROJECT`. If empty, tell the user and stop.
- `$ARGUMENTS` must be a single word containing only alphanumeric characters, hyphens, and underscores (e.g., `solver`, `solver_15-2`). No spaces or other special characters. If empty or invalid, tell the user and stop.

## Phase 0: Register the bot name

Bot names are globally unique per project, tracked in an issue titled `active bots`.

1. Get the GitLab username (not the system username):

       glab auth status 2>&1

   Parse the `Logged in to gitlab.com as <username>` line to extract the username.

2. Search for the registry issue:

       glab issue list -R "$GITLAB_REMOTE_PROJECT" --search "active bots" --in title

3. If not found, create it:

       glab issue create -R "$GITLAB_REMOTE_PROJECT" --title "active bots" --description "" --no-editor

4. Fetch the issue description:

       glab issue view <registry-iid> -R "$GITLAB_REMOTE_PROJECT"

5. Check if the bot name already exists in the description:
   - If `<botname>` appears and the owner is a **different** user → refuse and stop. Tell the user the name is taken.
   - If `<botname>` appears and the owner is the **same** user → proceed (resuming).
   - If `<botname>` does not appear → add a line `<botname> (<username>)` to the description:

         glab issue update <registry-iid> -R "$GITLAB_REMOTE_PROJECT" --description "<updated description>"

## Phase 1: Start listening

Start the mention watcher using the Monitor tool with `persistent: true`:

    bash ~/.claude/skills/bot/poll-mentions.sh "$GITLAB_REMOTE_PROJECT" "<botname>"

This polls every 10s. When someone comments `@<botname> ...` on any issue or MR, you receive a notification formatted as:

    [issue:<iid>] comment body
    [mr:<iid>] comment body
    [mr:<iid>:<discussion_id>] comment body

The third form appears when the mention is inside an MR discussion thread. The `discussion_id` is a hex string. No tokens are consumed while waiting.

## Phase 2: Handle a mention

When a Monitor notification arrives:

1. Parse the prefix: extract `type` (`issue` or `mr`), `iid`, and optionally `discussion_id` from the `[type:iid:discussion_id]` bracket.
2. Fetch full context:
   - For issues: `glab issue view <iid> -R "$GITLAB_REMOTE_PROJECT"`
   - For MRs: `glab mr view <iid> -R "$GITLAB_REMOTE_PROJECT"`
3. Write the session file so the Stop hook posts responses automatically. Get the current username and write:

   Write `/tmp/remote-session-<username>-<botname>.json` with:
   ```json
   {"project": "<GITLAB_REMOTE_PROJECT>", "type": "<issue|mr>", "iid": "<iid>", "prefix": "[<botname>]", "session_id": "<session_id>", "discussion_id": "<discussion_id or empty>"}
   ```

   Include `discussion_id` if present in the notification — this makes the Stop hook reply in the same MR thread instead of as a top-level comment. Omit it or set to empty string if not present.

   The `session_id` is available as `$CLAUDE_SESSION_ID` or from the session init message.

4. Work on the request described in the comment. The Stop hook will automatically post your response as a `[<botname>]` comment on the same issue/MR (in the correct thread if `discussion_id` was set).

## Phase 3: Continue listening

After responding, the Monitor is still running. Wait for the next `@<botname>` mention. When it arrives (possibly on a different issue/MR), update the session file with the new type and IID, then handle it.

This creates an infinite loop: listen → detect → respond → listen.

## Closing

When the user explicitly stops the bot:

1. Stop the Monitor using TaskStop.
2. Remove the bot from the `active bots` registry:
   - Fetch the registry issue description
   - Remove the line containing `<botname> (<username>)`
   - Update the description: `glab issue update <registry-iid> -R "$GITLAB_REMOTE_PROJECT" --description "<updated>"`

The session file in `/tmp` can be left alone — it's inert without the Monitor, the Stop hook won't match a dead session_id, and in sandboxed mode `/tmp` is a tmpfs that vanishes on exit.
