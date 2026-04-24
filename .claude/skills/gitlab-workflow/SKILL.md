---
name: gitlab-workflow
description: GitLab conventions — glab CLI, merge requests, semantic release. Use when working with GitLab issues, MRs, CI, or glab commands.
---

# GitLab

- Use the `glab` CLI for all GitLab interactions (issues, merge requests, projects, etc.)
- Example commands: `glab issue list`, `glab mr list`, `glab mr view <id>`, `glab issue view <id>`

## Merge Requests & Commits

**CRITICAL: All MR titles MUST follow conventional commit format.** Semantic release parses MR titles to determine version bumps - a missing or wrong prefix breaks automated releases.

- `feat: ...` - new feature or behavior change (triggers minor bump)
- `fix: ...` - bug fix (triggers patch bump)
- `chore: ...` / `ci: ...` / `docs: ...` - no release triggered
- `feat!: ...` / `fix!: ...` - breaking change (triggers major bump)

Individual commit messages do NOT use conventional prefixes - only the MR title.
