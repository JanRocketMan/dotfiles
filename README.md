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
- Shared `.aliases` file (claude, editors, tmux, ripgrep, SSH tunnel helpers, SLURM launchers)

First launch installs plugins automatically. Run `p10k configure` to set up prompt style.

### `.config/nvim/` — Neovim

[frozen.nvim](https://github.com/JanRocketMan/frozen.nvim) config (git submodule). Uses lazy.nvim — plugins install automatically on first launch.

### Sandbox — [nanobox](https://github.com/JanRocketMan/nanobox)

Claude runs inside a [nanobox](https://github.com/JanRocketMan/nanobox) sandbox by default (via the `claude` alias). Nanobox is an agent-agnostic bwrap+mitmproxy tool that confines any command to a minimal filesystem view — no root required.

```bash
claude                          # sandboxed via nanobox (alias)
claude --resume                 # args pass through transparently
claude-unsafe                   # unsandboxed, plan permission mode
```

### `.config/vifm/` — Vifm file manager

- `vifmrc` — config (codeyellow colorscheme)
- `colors/codeyellow.vifm` — symlink to nvim's copy (shared theme)

### Credential injection proxy

Managed by [nanobox](https://github.com/JanRocketMan/nanobox). Run `nbox proxy` to edit the credentials template, `nbox resolve` to generate `credentials.json` from env vars. The proxy auto-starts when launching sandboxed commands.

### `.config/slurm/` — SLURM cluster config

Configurable `slaunch` command for GPU job submission. Partition names and resources are defined in `cluster.conf` (machine-specific, gitignored).

```bash
slaunch standard 1 bash              # interactive shell, 1 GPU
slaunch standard 1 python train.py   # single GPU
slaunch small 8 python train.py      # 8 GPUs (auto torchrun)
slaunch hyper 2x8 python train.py    # 2 nodes × 8 GPUs
```

On a SLURM cluster, edit `~/.config/slurm/cluster.conf` with your partition names. Short aliases (`sbash`, `spython`, `s8python`, etc.) are auto-registered when `srun` is available.

## Requirements

- Linux or macOS (both supported by `install.sh`)
- No root/sudo needed
- `stow` (`apt install stow` / `brew install stow`)
