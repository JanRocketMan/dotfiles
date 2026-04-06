---
name: gitlab-workflow
description: GitLab conventions — MCP tools, glab CLI, merge requests, semantic release. Use when working with GitLab issues, MRs, CI, or glab commands.
---

# GitLab

- Use `gitlab` MCP tools for interacting with GitLab (issues, merge requests, projects, etc.)
- If the GitLab MCP server fails, is unavailable, or does not provide enough information, fall back to the `glab` CLI tool instead
- Example `glab` commands: `glab issue list`, `glab mr list`, `glab mr view <id>`, `glab issue view <id>`

## Merge Requests & Commits

- Projects use **semantic release** — the MR title must use conventional commit prefixes (`feat:`, `fix:`, `chore:`, etc.) so the release bot can determine version bumps.
- **Individual commit messages should NOT use conventional commit prefixes** (`feat:`, `fix:`, `test:`, etc.). Only the MR title needs them. Keep commit messages plain and descriptive.
