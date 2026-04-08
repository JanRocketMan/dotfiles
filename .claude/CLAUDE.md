# Personal Preferences

## VCS

Always use Jujutsu (`jj`) colocated with Git. Never run bare `git` commands.

- Ensure colocation: if only `.git/` exists → `jj git init --colocate`; if only `.jj/` (non-colocated) → ask before converting
- Remote operations: `jj git push`, `jj git fetch`

## Commits

- No conventional commit prefixes going forward (no `fix:`, `feat:`, `refactor:`, etc.)
- Use imperative mood, lowercase, ~50 char first line
- Describe what changed and why, not the category

