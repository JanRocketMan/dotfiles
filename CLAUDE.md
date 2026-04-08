# dotfiles

GNU Stow-managed dotfiles repo. The repo root mirrors `$HOME` — deploy with `stow .`.

- `.stow-local-ignore` excludes non-dotfile items (README, LICENSE, install.sh, TOOLS.md, .jj, .git)
- `install.sh` reads download URLs from `TOOLS.md` — no hardcoded URLs in scripts
- Shell: zsh with powerlevel10k, tmux, neovim
- `.claude/` contains Claude Code config (settings, skills, statusline) — also deployed via stow
