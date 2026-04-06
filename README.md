# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). The repo root mirrors `$HOME` — deploy everything with `stow .`.

## Setup

```bash
# Clone (--recurse-submodules pulls frozen.nvim)
git clone --recurse-submodules git@github.com:JanRocketMan/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Dry run (preview what will be symlinked)
stow -n -v .

# Deploy
stow .

# Install all tools (reads URLs from TOOLS.md)
bash install.sh
```

## Security: centralized dependency manifest

All external download URLs live in a single file: **[`TOOLS.md`](TOOLS.md)**.

`install.sh` reads this manifest at runtime — it contains **zero hardcoded URLs**. If a tool is compromised or a release needs pinning to a different version, edit one row in `TOOLS.md`. No need to grep through shell scripts.

This also makes auditing easy: `TOOLS.md` is the complete list of every remote resource this repo touches during installation.

## What's included

### `.claude/` — Claude Code config

- `CLAUDE.md` — personal instructions (jj preference, Python style)
- `settings.json` — permissions (allow/deny/ask), plugins
- `keybindings.json` — custom keybindings (vim-style navigation, ctrl shortcuts)
- `statusline-command.sh` — status line showing model, effort, project, VCS branch, context bar
- `skills/` — on-demand skills for GitLab and Jira workflows

### `.zshrc` / `.zshenv` / `.aliases` — Zsh

Fish-like zsh setup with zinit plugin manager:
- **Powerlevel10k** prompt, **autosuggestions**, **history-substring-search**, **syntax-highlighting**
- **fzf** integration for fuzzy history (Ctrl+R)
- Sources `.bashrc` first for SLURM/module compatibility
- Shared `.aliases` file (claude, editors, tmux, ripgrep, SSH tunnel helpers)

First launch installs plugins automatically. Run `p10k configure` to set up prompt style.

### `.config/nvim/` — Neovim

[frozen.nvim](https://github.com/JanRocketMan/frozen.nvim) config (git submodule). Uses lazy.nvim — plugins install automatically on first launch.

### `.local/bin/claude-sandbox` — Bubblewrap sandbox for Claude Code

Confines Claude Code to a minimal filesystem view using Linux user namespaces — no root required.

- SSH private keys invisible (auth via ssh-agent socket)
- `.env` files masked to `/dev/null`
- Environment wiped clean (`env -i`), only essential vars forwarded
- `.venv` read-only, project dir read-write
- Optional `--proxy` flag for mitmproxy-based credential injection

```bash
claude ~/myproject              # sandboxed (alias for claude-sandbox)
claude --proxy ~/myproject      # with credential injection
claude-unsafe                   # unsandboxed, plan permission mode
```

### `.config/vifm/` — Vifm file manager

- `vifmrc` — config (codeyellow colorscheme)
- `colors/codeyellow.vifm` — symlink to nvim's copy (shared theme)

### `.config/proxy-creds/` — Credential injection proxy

- `inject_credentials.py` — mitmproxy addon for header injection
- `credentials.json.example` — template for API token mapping

## Requirements

- Linux or macOS (both supported by `install.sh`)
- No root/sudo needed
- `stow` (`apt install stow` / `brew install stow`)
