# Personal Preferences

## Coding style

Follow the YAGNI rule - the best code is code never written.

When writing and/or editing code, stop at the first rung that holds:

1. **Does this need to exist at all?** Speculative need = skip it, say so in one line (YAGNI)
2. **Already in this codebase?** A helper, util, type or pattern that already lives here -> reuse it. Look before you write; re-implementing what's a few files over is the most common slop
3. **Stdlib does it?** Use it
4. **Native platform feature covers it?** `<input type="date">` over a picker lib, CSS over JS, DB constraint over app code
5. **Already-installed dependency solves it?** Use it. Never add a new one for what a few lines can do
6. **Can it be one line?** One line
7. **Only then:** the minimum code that works

The ladder is a reflex, not a research project - but it runs **after** you understand the problem, not instead of it. Read the task and the code it touches first, trace the real flow end-to-end, then climb. Two rungs work -> take the higher one and move on. The first lazy solution that works is the right one - once you actually know what the change has to touch.

When fixing bugs, fix the root cause, not symptom. The lazy fix IS the root-cause fix.

- No unrequested abstractions: no interface with one implementation, no factory for one product, no config for a value that never changes
- No boilerplate, no scaffolding "for later", later can scaffold for itself
- Deletion over addition. Boring over clever, clever is what someone decodes at 3am
- Fewest files possible. Shortest working diff wins - but only once you understand the problem. The smallest change in the wrong place isn't lazy, it's a second bug
- Complex request? Ship the lazy version and question it in the same response, "Did X; Y covers it. Need full X? Say so." Never stall on an answer you can default
- Two stdlib options, same size? Take the one that's correct on edge cases. Lazy means writing less code, not picking the flimsier algorithm
- Avoid the long parameter lists in functions and class methods definitions
- Arrange your code to communicate data flow - e.g. declare the local variables as close to the first use as possible

## Comments

- Mark deliberate code simplifications that cut a real corner with a know ceiling (global lock, O(n²) scan, naive heuristic) in a comment above the code
- Use self-contained comments to clearly convey intent without relying on the surrounding code for context
- Include only essential information in the comments and leverage external references to reduce cognitive load on the reader
- Avoid extensive implementation details in function-level comment
- Omit comments that state the obvious

## Writing tests

- The tests should check the behaviour of the code, not pattern-match it
- Never write change-detector tests - a test that mirrors the implementation catches no defects and breaks on every refactor, so delete or re-write it instead of fixing it
- Use mocks only when the real implementation is too slow and/or unaccessible and the fake implementation is unavailable
- Prefer narrow assertions in unit tests
- Make test failures actionable - if someone breaks, the caller should be able to begin investigation with nothing more than the test’s name and its failure messages

## Writing style

- Write all responses and Markdown files in ASD-STE100 Simplified Technical English
- Follow Zinsser's four principles of quality writing: simplicity, brevity, clarity, and humanity
- Use regular dashes (`-`) instead of em dashes (`—`)
- Use minimal end punctuation in user-facing prose when the layout already shows the text boundary:
  - Omit the period at the end of a paragraph, standalone text block, heading, or list item
  - Apply this rule to list items even when they are complete sentences
  - Keep periods between sentences in the same paragraph
  - Keep a question mark or exclamation mark when the meaning requires it
  - Do not replace an omitted period with a comma or semicolon
- Use standard end punctuation in text that a UI can concatenate:
  - End each distinct thought in reasoning traces, progress messages, logs, and streamed text with a period
  - Do not use line breaks, block boundaries, or trailing spaces as the only separator
- Preserve exact punctuation in code, commands, paths, URLs, version numbers, abbreviations, direct quotations, and other literal text
- Dont write essays, feature tours or design notes unless specifically asked by user

## VCS

Always use Jujutsu (`jj`) colocated with Git. Never run bare `git` commands.

- Ensure colocation: if only `.git/` exists → `jj git init --colocate`; if only `.jj/` (non-colocated) → ask before converting
- Use remote operations with `jj` commands: `jj git push`, `jj git fetch`
- Dont use any prefixes in commit messages (no `fix:`, `feat:` etc.)
- Use imperative mood in commit messages, lowercase, ~50 char first line
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
- Imports (PEP 8, PEP 328):
  - All imports at the top of the file, never inside functions or local scopes
  - Order: stdlib → third-party → local; prefer relative imports within packages
  - Never use wildcard imports (`from lib import *`) - always import specific names (PEP 8)
  - Use `ruff check --select I --fix` (isort) to sort and format imports

