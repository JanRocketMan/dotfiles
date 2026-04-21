---
name: sync-nvim
description: Sync the .config/nvim directory from dotfiles to the frozen.nvim GitHub repo. Stops and reports only on conflicts.
user-invocable: true
allowed-tools: "Bash Read Glob"
---

# Sync nvim config to frozen.nvim

Push the current `.config/nvim` contents from this dotfiles repo to `git@github.com:JanRocketMan/frozen.nvim.git`.

## Procedure

1. **Prepare a temp working copy** of frozen.nvim:
   ```
   WORK=$(mktemp -d)
   git clone --depth=1 git@github.com:JanRocketMan/frozen.nvim.git "$WORK"
   ```

2. **Sync files** — mirror `.config/nvim/` into the working copy, excluding `.git`:
   ```
   rsync -a --delete --exclude='.git' --exclude='.jj' <dotfiles>/.config/nvim/ "$WORK/"
   ```

3. **Check for changes** — if `git status` in `$WORK` shows nothing, report "already up to date" and clean up.

4. **Commit and push**:
   ```
   cd "$WORK"
   jj git init --colocate
   jj describe -m "<summary of what changed>"
   jj bookmark set main -r @
   jj git push
   ```
   Generate the commit message by looking at the diff — use the same style as the dotfiles repo (imperative, lowercase, ~50 chars).

5. **Clean up** the temp directory.

## Conflict handling

If `jj git push` fails due to conflicts (remote has commits not in the clone), **STOP** and report the error to the user. Do not force-push or rebase without asking.

## What to exclude

Do not sync these to frozen.nvim (they belong only in dotfiles):
- `.git/`, `.jj/` directories
- Any files listed in `.config/nvim/.gitignore`
