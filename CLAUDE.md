# dotfiles

GNU Stow-managed dotfiles repo. The repo root mirrors `$HOME` — deploy with `stow --no-folding .`.

- `--no-folding` is required: without it, on a fresh machine stow tree-folds `~/.local` and `~/.config` into single symlinks pointing back into this repo, so `install.sh`'s downloaded toolchain (and app state) lands in the repo tree instead of `$HOME`.

- `.stow-local-ignore` excludes non-dotfile items (README, LICENSE, install.sh, TOOLS.md, .jj, .git)
- `install.sh` reads download URLs from `TOOLS.md` — no hardcoded URLs in scripts
- Shell: zsh with powerlevel10k, tmux, neovim
- `.claude/` contains Claude Code config (settings, skills, statusline) — also deployed via stow
