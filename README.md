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

# Install claude-sandbox dependencies (bwrap, mitmproxy, CA certs)
bash install.sh
```

## What's included

### `.claude/` — Claude Code config

- `CLAUDE.md` — personal instructions (jj preference, Python style, GitLab workflow)
- `settings.json` — permissions (allow/deny/ask), plugins, MCP servers
- `keybindings.json` — custom keybindings (vim-style navigation, ctrl shortcuts)
- `statusline-command.sh` — status line showing model, effort, project, VCS branch, context bar

### `.zshrc` / `.zshenv` — Zsh

Fish-like zsh setup with zinit plugin manager:
- **Powerlevel10k** — fast prompt with git status, shortened paths
- **zsh-autosuggestions** — inline grey suggestions from history (accept with →)
- **zsh-history-substring-search** — type partial command, press ↑/↓ to match
- **zsh-syntax-highlighting** — command coloring like fish
- **fzf** integration for fuzzy history search (Ctrl+R)

First launch installs plugins automatically. Run `p10k configure` to set up prompt style.

### `.config/nvim/` — Neovim

[frozen.nvim](https://github.com/JanRocketMan/frozen.nvim) config (git submodule). Uses lazy.nvim — plugins install automatically on first launch.

Update to latest:
```bash
git submodule update --remote .config/nvim
```

### `.local/bin/claude-sandbox` — Bubblewrap sandbox for Claude Code

Confines Claude Code to a minimal filesystem view using Linux user namespaces — no root required.

- SSH private keys invisible (auth via ssh-agent socket)
- `.env` files masked to `/dev/null`
- Environment wiped clean (`env -i`), only essential vars forwarded
- `.venv` read-only, project dir read-write
- Optional `--proxy` flag for mitmproxy-based credential injection

```bash
claude-sandbox ~/myproject              # basic sandbox
claude-sandbox --proxy ~/myproject      # with credential injection
claude-sandbox --shell ~/myproject      # debug with bash
claude-sandbox --dry-run ~/myproject    # see the full bwrap command
```

### `.config/vifm/` — Vifm file manager

- `vifmrc` — config (sets codeyellow colorscheme)
- `colors/codeyellow.vifm` — symlink to `.config/nvim/colors/codeyellow.vifm` (shared theme)

### `.config/proxy-creds/` — Credential injection proxy

- `inject_credentials.py` — mitmproxy addon for header injection
- `credentials.json.example` — template for API token mapping (copy to `credentials.json` and fill in)

## Requirements

- Linux with user namespaces enabled (`cat /proc/sys/kernel/unprivileged_userns_clone` → 1)
- No root/sudo needed
- `stow` (usually pre-installed or `apt install stow`)
- `uv` (for mitmproxy install, optional)
