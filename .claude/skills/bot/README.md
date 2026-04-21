# /bot — GitLab mention-driven agent

A Claude Code skill that creates a named bot watching a GitLab project for `@mentions` in issues and MRs.

## How it works

```
You (phone/browser)                    Your machine
    |                                      |
    |  @solver review this function        |
    |  (comment on issue or MR thread)     |
    |                                      |
    +---- GitLab ---- poll-mentions.sh --->| Claude Code picks up the mention
                                           | via Monitor tool (polls every 10s)
                                           |
                                           | Agent reads context, works on it
                                           |
                      post-response.sh <---| Stop hook auto-posts response
                      (Stop hook)          | as [solver] comment on the same
                           |               | issue/MR thread
                           v               |
                        GitLab             | Agent goes back to listening
```

## Setup

### 1. Install and authenticate glab

```bash
# Install glab (GitLab CLI)
# See: https://gitlab.com/gitlab-org/cli#installation

glab auth login
```

### 2. Set your project

```bash
export GITLAB_REMOTE_PROJECT="group/project"
```

### 3. Register the Stop hook

Add to `~/.claude/settings.json` under `hooks`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/skills/bot/post-response.sh"
          }
        ]
      }
    ]
  }
}
```

### 4. Start a bot

```
/bot solver
```

This creates a bot named `solver` that:
- Registers in the project's `active bots` issue (prevents name collisions)
- Watches for `@solver` mentions across all issues and MRs
- Responds in-place with `[solver]` prefix (in the same discussion thread for MRs)
- Loops back to listening after each response

## Usage

Once the bot is running, mention it anywhere in the project:

```
@solver what does this function do?
@solver review this MR
@solver is this bug still present on main?
```

The bot picks up the mention, fetches context from the issue/MR, works on it, and posts a `[solver]` reply. For MR discussion threads, it replies in the same thread.

## Bot name rules

Bot names must contain only alphanumeric characters, hyphens, and underscores. Examples:
- `solver` — valid
- `solver_15-2` — valid
- `solver 15` — invalid (contains space)

## Multi-user support

- Bot names are unique per project, tracked in an `active bots` issue
- Session files include the GitLab username (from `glab auth status`): `/tmp/remote-session-<user>-<bot>.json`
- Multiple users can run different bots on the same project simultaneously
- The Stop hook matches responses to sessions by `session_id`, preventing cross-talk

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill definition (instructions for Claude Code) |
| `poll-mentions.sh` | Polls GitLab Events API for `@botname` mentions, resolves MR discussion threads |
| `poll-comments.sh` | Polls issue comments (used by related remote skills) |
| `post-response.sh` | Stop hook — auto-posts agent responses to GitLab issues/MRs/threads |

## Limitations

- **Polling, not webhooks** — ~10s latency between mention and pickup
- **Single-threaded** — one mention at a time per bot instance
- **Bot name characters** — alphanumeric, hyphens, and underscores only
