# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

### `claude-sandbox`

Bubblewrap-based sandbox for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Confines the AI agent to a minimal filesystem view using Linux user namespaces — no root required.

**What it protects:**
- SSH private keys are invisible (auth via ssh-agent socket)
- `.env` files are masked to `/dev/null`
- Environment is wiped clean (`env -i`), only essential vars forwarded
- `.venv` is read-only, project dir is read-write
- Other home directory contents don't exist in the sandbox

**Optional:** `--proxy` flag starts a mitmproxy-based credential injection proxy that intercepts HTTPS requests and injects auth headers. The sandbox never sees real API tokens.

## Setup

```bash
# Clone
git clone git@github.com:JanRocketMan/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Symlink into home directory
stow claude-sandbox

# Install dependencies (bwrap, mitmproxy, CA certs, known_hosts)
bash claude-sandbox/install.sh
```

## Usage

```bash
# Basic — sandbox Claude to one project directory
claude-sandbox ~/myproject

# With credential injection proxy
claude-sandbox --proxy ~/myproject

# Extra read-only mounts (e.g. CUDA on a cluster)
claude-sandbox --ro /cm/shared ~/myproject

# Debug the sandbox with a shell
claude-sandbox --shell ~/myproject -- -c 'ls ~/.ssh'

# See the full bwrap command
claude-sandbox --dry-run ~/myproject
```

## Files

After `stow claude-sandbox`, these symlinks are created:

```
~/.local/bin/claude-sandbox              → Main launcher script
~/.config/proxy-creds/inject_credentials.py  → mitmproxy addon
~/.config/proxy-creds/credentials.json.example → Template for API token mapping
```

Generated during `install.sh` (not version-controlled):

```
~/.local/bin/bwrap                       → Bubblewrap binary (from .deb)
~/.mitmproxy/                            → mitmproxy CA certs
~/.mitmproxy/combined-ca.pem             → System CAs + mitmproxy CA
~/.config/proxy-creds/credentials.json   → Your real API token mapping
```

## Requirements

- Linux with user namespaces enabled (`cat /proc/sys/kernel/unprivileged_userns_clone` → 1)
- No root/sudo needed
- `stow` (usually pre-installed or `apt install stow`)
- `uv` (for mitmproxy install, optional)
