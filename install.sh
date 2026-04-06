#!/usr/bin/env bash
set -euo pipefail

# install.sh — Bootstrap dotfiles dependencies on a new machine.
# Run AFTER `stow .` has symlinked everything into place.

echo "=== Installing dotfiles dependencies ==="

# 1. Install bubblewrap (no sudo required)
if command -v bwrap &>/dev/null; then
    echo "[ok] bwrap already installed: $(bwrap --version)"
else
    echo "[..] Installing bwrap from .deb..."
    TMPDIR="$(mktemp -d)"
    (
        cd "$TMPDIR"
        apt download bubblewrap 2>/dev/null
        mkdir extract
        dpkg -x bubblewrap_*.deb extract
        cp extract/usr/bin/bwrap "$HOME/.local/bin/bwrap"
        chmod +x "$HOME/.local/bin/bwrap"
    )
    rm -rf "$TMPDIR"
    echo "[ok] bwrap installed: $(bwrap --version)"
fi

# 2. Install mitmproxy (optional, for --proxy flag)
if command -v mitmdump &>/dev/null; then
    echo "[ok] mitmdump already installed: $(mitmdump --version 2>&1 | head -1)"
else
    if command -v uv &>/dev/null; then
        echo "[..] Installing mitmproxy via uv..."
        uv tool install mitmproxy
        echo "[ok] mitmdump installed"
    else
        echo "[skip] mitmproxy not installed (uv not found). Install manually for --proxy support."
    fi
fi

# 3. Generate mitmproxy CA certs (if mitmdump is available)
if command -v mitmdump &>/dev/null && [[ ! -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]]; then
    echo "[..] Generating mitmproxy CA certificates..."
    timeout 3 mitmdump --listen-host 127.0.0.1 --listen-port 18099 &>/dev/null || true
    echo "[ok] CA certs generated in ~/.mitmproxy/"
fi

# 4. Create combined CA bundle
if [[ -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]]; then
    SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
    if [[ -f "$SYSTEM_CA" ]]; then
        cat "$SYSTEM_CA" "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" > "$HOME/.mitmproxy/combined-ca.pem"
        echo "[ok] Combined CA bundle created"
    else
        echo "[warn] System CA bundle not found at $SYSTEM_CA — skip combined CA"
    fi
fi

# 5. Pre-populate SSH known_hosts
echo "[..] Adding GitHub/GitLab to known_hosts..."
ssh-keyscan github.com gitlab.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo "[ok] known_hosts updated"

# 6. Create credentials.json from example if missing
CRED_FILE="$HOME/.config/proxy-creds/credentials.json"
CRED_EXAMPLE="$HOME/.config/proxy-creds/credentials.json.example"
if [[ ! -f "$CRED_FILE" ]] && [[ -f "$CRED_EXAMPLE" ]]; then
    cp "$CRED_EXAMPLE" "$CRED_FILE"
    echo "[ok] Created $CRED_FILE from example — edit it with your real tokens"
else
    echo "[ok] $CRED_FILE already exists"
fi

# 7. Install vifm (no sudo required)
VIFM_VERSION="0.14"
if command -v vifm &>/dev/null; then
    echo "[ok] vifm already installed: $(vifm --version 2>&1 | head -1)"
else
    echo "[..] Installing vifm ${VIFM_VERSION}..."
    TMPDIR="$(mktemp -d)"
    ARCH="$(uname -m)"
    (
        cd "$TMPDIR"
        wget -q "https://github.com/vifm/vifm/releases/download/v${VIFM_VERSION}/vifm-v${VIFM_VERSION}-${ARCH}.tar.gz" \
            -O vifm.tar.gz
        tar xzf vifm.tar.gz
        cp vifm-v${VIFM_VERSION}-${ARCH}/vifm "$HOME/.local/bin/vifm"
        chmod +x "$HOME/.local/bin/vifm"
    )
    rm -rf "$TMPDIR"
    echo "[ok] vifm installed: $(vifm --version 2>&1 | head -1)"
fi

# 8. Install zinit plugin manager for zsh
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ -d "$ZINIT_HOME" ]]; then
    echo "[ok] zinit already installed"
else
    echo "[..] Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    echo "[ok] zinit installed"
fi

# 9. Install fzf (no sudo required)
if command -v fzf &>/dev/null; then
    echo "[ok] fzf already installed: $(fzf --version 2>&1 | head -1)"
else
    echo "[..] Installing fzf..."
    TMPDIR="$(mktemp -d)"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  FZF_ARCH="amd64" ;;
        aarch64) FZF_ARCH="arm64" ;;
        *)       FZF_ARCH="$ARCH" ;;
    esac
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    FZF_VERSION="$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v')"
    (
        cd "$TMPDIR"
        wget -q "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${OS}_${FZF_ARCH}.tar.gz" \
            -O fzf.tar.gz
        tar xzf fzf.tar.gz
        cp fzf "$HOME/.local/bin/fzf"
        chmod +x "$HOME/.local/bin/fzf"
    )
    rm -rf "$TMPDIR"
    echo "[ok] fzf installed: $(fzf --version 2>&1 | head -1)"
fi

# 10. Set zsh as default shell
ZSH_PATH="$(command -v zsh 2>/dev/null)"
if [[ -n "$ZSH_PATH" && "$SHELL" != *"zsh"* ]]; then
    if chsh -s "$ZSH_PATH" 2>/dev/null; then
        echo "[ok] Default shell set to $ZSH_PATH"
    else
        # chsh may need sudo — add exec to .bash_profile instead of .bashrc
        # (.zshrc sources .bashrc, so putting exec in .bashrc would loop)
        PROFILE="$HOME/.bash_profile"
        EXEC_LINE="[[ -x $ZSH_PATH && -z \$ZSH_VERSION ]] && exec $ZSH_PATH -l"
        if ! grep -qF "exec $ZSH_PATH" "$PROFILE" 2>/dev/null; then
            echo "" >> "$PROFILE"
            echo "# Auto-switch to zsh on login (no sudo for chsh)" >> "$PROFILE"
            echo "$EXEC_LINE" >> "$PROFILE"
            echo "[ok] Added zsh exec to $PROFILE (chsh unavailable without sudo)"
        else
            echo "[ok] $PROFILE already execs zsh"
        fi
    fi
else
    if [[ -n "$ZSH_PATH" ]]; then
        echo "[ok] Default shell is already zsh"
    else
        echo "[warn] zsh not found. Install it first (apt install zsh / brew install zsh)"
    fi
fi

echo ""
echo "=== Done ==="
echo ""
echo "Usage:"
echo "  claude-sandbox ~/myproject              # basic sandbox"
echo "  claude-sandbox --proxy ~/myproject       # with credential injection"
echo "  claude-sandbox --shell ~/myproject       # debug with bash"
echo "  vifm                                     # file manager"
echo "  zsh                                      # start zsh (plugins install on first launch)"
echo ""
echo "Edit ~/.config/proxy-creds/credentials.json to add your API tokens for --proxy mode."
echo "Run 'p10k configure' to set up your prompt style."
