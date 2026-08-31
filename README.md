# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). The repo root mirrors `$HOME` — deploy everything with `stow --no-folding .`.

## Setup

```bash
# Clone (--recurse-submodules pulls frozen.nvim)
git clone --recurse-submodules git@github.com:JanRocketMan/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Dry run (preview what will be symlinked)
stow -n -v --no-folding .

# Deploy
# --no-folding forces real directories + per-file symlinks. Without it, on a
# fresh machine stow "folds" ~/.local and ~/.config into single symlinks back
# into this repo, so install.sh's downloads and app state pollute the repo tree.
stow --no-folding .

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
- `skills/` - on-demand skills for GitLab, Jira, and shared PDB workflows

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

Claude, Pi, Tau, and Codex run inside a [nanobox](https://github.com/JanRocketMan/nanobox) sandbox by default. Nanobox is an agent-agnostic bwrap+mitmproxy tool that confines any command to a minimal filesystem view - no root required.

```bash
claude                          # sandboxed via nanobox
claude --resume                 # args pass through transparently
claude-unsafe                   # explicit unsandboxed launch
tau                             # sandboxed via nanobox
pdbox python train.py           # dedicated sandboxed PDB debuggee pane
tau --debug                     # share one same-project sandboxed PDB pane
tau --debug=%12                 # select an explicit PDB pane
```

For shared debugging, start the debuggee with `pdbox python ...` in one tmux pane and wait at `breakpoint()`. `pdbox` replaces the host shell with a nanobox `--debuggee` run, so the pane closes instead of returning to a host shell. Start `tau --debug` from the same project directory in another pane. The conditional `.tau/extensions/nbox_pdb.py` extension gives Tau a `pdb` tool only for that run

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
