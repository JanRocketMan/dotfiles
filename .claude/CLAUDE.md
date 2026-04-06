# Personal Preferences

## VCS

This project uses Jujutsu (`jj`), not Git directly.

- Always use `jj` commands instead of `git` commands.
- Use `jj log` instead of `git log`, `jj diff` instead of `git diff`, etc.
- The only acceptable use of `git` is through `jj git` subcommands (e.g. `jj git push`, `jj git fetch`).
- Never run bare `git` commands — they can corrupt jj's co-located repo state.

## Jira

To work with jira use `acli jira` tool. If its not installed or configured ask the user to do this.

### Assignee

- Do **not** use `@me` for assignee — it may resolve to the wrong account.
- Instead, retrieve the current user's email via `acli jira auth status` and use that email explicitly in all ticket creation and assignment commands.

### Defaults

- Always transition newly created tickets to **"To Do"** status after creation.

### Boards

Default to the **AI Lab | GTE** board unless the user explicitly mentions AM or Access Management.

- **AI Lab | GTE** (PAIR project, default): Use JQL `project = PAIR AND issuetype IN (Bug, Story, Task, Sub-task) AND component = "PAIR ML Nikita" ORDER BY created DESC`
- **Access Management (AM)**: For access-related tickets, search the AM board instead: `project = AM AND project = am AND filter != "Reject update 1 week" ORDER BY Rank DESC`

## Python

### Tooling

Always use `uv` for Python project management instead of pip, venv, conda, poetry, or pipenv.

- Create venvs: `uv venv`
- Install packages: `uv pip install <package>`
- Run scripts: `uv run python script.py` or `uv run pytest`
- Add deps: `uv add <package>`, `uv add --dev <package>`
- Target version: Python 3.10+
- Formatter/linter: Ruff (line length 120, F401 ignored)
- Type checking: Pyright in `basic` mode
- Testing: pytest

### Style

- Type-annotate all function signatures (params + return); skip local variables.
  Use modern syntax: `str | None`, `list[int]` (not `Optional`, `List`)
- No `from __future__ import annotations`
- Data modeling: Pydantic for services/APIs, dataclasses for internal, dataclasses + pyrallis for CLI apps
- Web framework: FastAPI
- Logging: stdlib `logging` (or `loguru` if project already uses it)
- Async: `asyncio` when beneficial for I/O; sync by default
- Paths: always `pathlib.Path`, never `os.path`
- Strings: f-strings for all interpolation
- Docstrings: Google style (`Args:`, `Returns:`, `Raises:`); skip for trivial code
- Imports: stdlib → third-party → local; prefer relative imports within packages


## GitLab

- Use `gitlab` MCP tools for interacting with GitLab (issues, merge requests, projects, etc.)
- If the GitLab MCP server fails, is unavailable, or does not provide enough information, fall back to the `glab` CLI tool instead
- Example `glab` commands: `glab issue list`, `glab mr list`, `glab mr view <id>`, `glab issue view <id>`

### Merge Requests & Commits

- Projects use **semantic release** — the MR title must use conventional commit prefixes (`feat:`, `fix:`, `chore:`, etc.) so the release bot can determine version bumps.
- **Individual commit messages should NOT use conventional commit prefixes** (`feat:`, `fix:`, `test:`, etc.). Only the MR title needs them. Keep commit messages plain and descriptive.
