---
name: report-issues
description: |
  Maintain a persistent ISSUES.md ledger at the root of the current repository.
  Use whenever work on a task surfaces problems - stale code, bad tests,
  outdated docs, workarounds, unverifiable changes, anything that cost time or
  will cost time later. Record issues as they are noticed, without waiting for
  the user to ask. Also use when the user asks what issues were noted, asks to
  review or summarize the ledger, or says complain, gripe, file an issue, or
  report a problem.
license: MIT
metadata:
  version: "1.0.0"
user-invocable: true
---

# Issue ledger

Keep a file named `ISSUES.md` at the root of the current repository (the directory that contains `.git`; for directories that are not a git repo, the current working directory). One file per repository, shared by all sessions that work in that repo.

`ISSUES.md` is a local working note. Do not commit it to git and do not add it to any commit unless the user explicitly asks.

## When to record

Record issues while working, at the moment you notice them. Do not wait for the task to finish and do not wait for the user to ask. When the task ends, do one final pass over what you encountered and record anything you noticed but did not record yet.

Record when you find:

- **stale-code** - code, comments, config, or docs that describe a reality that no longer matches the codebase
- **bad-test** - a test that is wrong, weak, flaky, skipped, or that you had to change or work around to make progress
- **dead-end** - docs, examples, or tooling that sent you down a path that did not work
- **shortcut** - something you left incomplete, simplified, or worked around, and you know it will cost time later
- **risk** - a change whose side effects you could not verify (unknown callers, missing tests, silent failure modes)

Do not record cosmetic preferences, style nits, or issues you fixed and verified on the spot.

## Entry format

Create `ISSUES.md` with the header below when you record the first entry. Add new entries at the top of the file, below the header, newest first.

```markdown
# ISSUES.md

Working issue ledger for this repository. One entry per noticed problem. Local note, not committed.

Categories: stale-code | bad-test | dead-end | shortcut | risk
Severity: high | medium | low
Mark fixed entries with [fixed] in the title.
```

Entry template:

```markdown
## [severity] [category]: one-line title

- **Where**: path/to/file:line, or a precise description of the location
- **What**: two or three sentences on what is wrong
- **Dealt with**: what you did about it, or "left as is"
```

## Rules

1. Read `ISSUES.md` before recording. If it does not exist, assume no prior entries.
2. Dedupe - do not record an issue that is already in the file. If a new entry covers the same area as an existing one, update the existing entry instead.
3. Mark fixed - when you notice an entry describes an issue that is already resolved, mark it with [fixed] in the title. When you fix an issue yourself, mark it the same way.
4. Never delete entries unless the user asks.
5. Keep entries short. One entry per problem.

## When invoked

When invoked as `/report-issues`:
- If the ledger does not exist, say the ledger is empty.
- Otherwise summarize the open entries grouped by severity and category, and propose the cheapest entry to fix now.
