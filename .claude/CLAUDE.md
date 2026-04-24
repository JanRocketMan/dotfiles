# Personal Preferences

## VCS

Always use Jujutsu (`jj`) colocated with Git. Never run bare `git` commands.

- Ensure colocation: if only `.git/` exists → `jj git init --colocate`; if only `.jj/` (non-colocated) → ask before converting
- Remote operations: `jj git push`, `jj git fetch`

## Writing style

- Never use em dashes (`—`); use regular dashes (`-`) instead

## Commits

- No conventional commit prefixes going forward (no `fix:`, `feat:`, `refactor:`, etc.)
- Use imperative mood, lowercase, ~50 char first line
- Describe what changed and why, not the category

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

