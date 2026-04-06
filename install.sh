#!/usr/bin/env bash
set -euo pipefail

# install.sh — Bootstrap dotfiles dependencies on a new machine.
# Run AFTER `stow .` has symlinked everything into place.
#
# All tools are installed to ~/.local/bin/ (no sudo required).
# Existing installations are skipped.

mkdir -p "$HOME/.local/bin"

# ── Helpers ───────────────────────────────────────────────────────────────────

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# Map arch names for tools that use amd64/arm64 convention
case "$ARCH" in
    x86_64)  ARCH_ALT="amd64" ;;
    aarch64) ARCH_ALT="arm64" ;;
    *)       ARCH_ALT="$ARCH" ;;
esac

# Install a tool from a GitHub release tarball
# Usage: gh_install NAME VERSION URL [BINARY_PATH]
#   BINARY_PATH is the path to the binary inside the extracted archive (default: NAME)
gh_install() {
    local name="$1" version="$2" url="$3" bin_path="${4:-$1}"
    if command -v "$name" &>/dev/null; then
        echo "[ok] $name already installed: $("$name" --version 2>&1 | head -1)"
        return
    fi
    echo "[..] Installing $name $version..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        wget -q "$url" -O archive.tar.gz
        tar xzf archive.tar.gz
        cp "$bin_path" "$HOME/.local/bin/$name"
        chmod +x "$HOME/.local/bin/$name"
    )
    rm -rf "$tmpdir"
    echo "[ok] $name installed: $("$name" --version 2>&1 | head -1)"
}

echo "=== Installing dotfiles dependencies ==="

# ── CLI tools ─────────────────────────────────────────────────────────────────

# ripgrep
RG_VERSION="14.1.0"
gh_install rg "$RG_VERSION" \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${ARCH}-unknown-${OS}-musl.tar.gz" \
    "ripgrep-${RG_VERSION}-${ARCH}-unknown-${OS}-musl/rg"

# fd
FD_VERSION="10.1.0"
gh_install fd "$FD_VERSION" \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${ARCH}-unknown-${OS}-musl.tar.gz" \
    "fd-v${FD_VERSION}-${ARCH}-unknown-${OS}-musl/fd"

# fzf
FZF_VERSION="0.62.0"
gh_install fzf "$FZF_VERSION" \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${OS}_${ARCH_ALT}.tar.gz" \
    "fzf"

# jq
JQ_VERSION="1.7.1"
if command -v jq &>/dev/null; then
    echo "[ok] jq already installed: $(jq --version 2>&1)"
else
    echo "[..] Installing jq $JQ_VERSION..."
    case "$ARCH" in
        x86_64)  JQ_ARCH="amd64" ;;
        aarch64) JQ_ARCH="arm64" ;;
        *)       JQ_ARCH="$ARCH" ;;
    esac
    wget -q "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${OS}-${JQ_ARCH}" \
        -O "$HOME/.local/bin/jq"
    chmod +x "$HOME/.local/bin/jq"
    echo "[ok] jq installed: $(jq --version 2>&1)"
fi

# ── Editors & file managers ───────────────────────────────────────────────────

# Neovim
NVIM_VERSION="0.10.3"
if command -v nvim &>/dev/null; then
    echo "[ok] nvim already installed: $(nvim --version 2>&1 | head -1)"
else
    echo "[..] Installing nvim $NVIM_VERSION..."
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        wget -q "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-${OS}-${ARCH}.tar.gz" \
            -O nvim.tar.gz
        tar xzf nvim.tar.gz
        # nvim ships as a directory with bin/, lib/, share/ — move whole tree
        rm -rf "$HOME/nvim-linux64"
        mv nvim-${OS}-${ARCH} "$HOME/nvim-linux64"
    )
    rm -rf "$tmpdir"
    echo "[ok] nvim installed: $(nvim --version 2>&1 | head -1)"
fi

# vifm
VIFM_VERSION="0.14"
gh_install vifm "$VIFM_VERSION" \
    "https://github.com/vifm/vifm/releases/download/v${VIFM_VERSION}/vifm-v${VIFM_VERSION}-${ARCH}.tar.gz" \
    "vifm-v${VIFM_VERSION}-${ARCH}/vifm"

# ── VCS ───────────────────────────────────────────────────────────────────────

# Jujutsu (jj)
JJ_VERSION="0.28.2"
if command -v jj &>/dev/null; then
    echo "[ok] jj already installed: $(jj version 2>&1)"
else
    echo "[..] Installing jj $JJ_VERSION..."
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        wget -q "https://github.com/jj-vcs/jj/releases/download/v${JJ_VERSION}/jj-v${JJ_VERSION}-${ARCH}-unknown-${OS}-musl.tar.gz" \
            -O jj.tar.gz
        tar xzf jj.tar.gz
        cp jj "$HOME/.local/bin/jj"
        chmod +x "$HOME/.local/bin/jj"
    )
    rm -rf "$tmpdir"
    echo "[ok] jj installed: $(jj version 2>&1)"
fi

# ── Python tooling ────────────────────────────────────────────────────────────

# uv
if command -v uv &>/dev/null; then
    echo "[ok] uv already installed: $(uv --version 2>&1)"
else
    echo "[..] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "[ok] uv installed: $(uv --version 2>&1)"
fi

# ── Claude Code ───────────────────────────────────────────────────────────────

if command -v claude &>/dev/null 2>&1; then
    echo "[ok] claude already installed: $(command claude --version 2>&1 | head -1)"
else
    echo "[..] Installing Claude Code..."
    # Claude Code installs via npm — requires node
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        echo "[ok] claude installed: $(command claude --version 2>&1 | head -1)"
    else
        echo "[skip] Claude Code requires npm. Install Node.js first, then: npm install -g @anthropic-ai/claude-code"
    fi
fi

# ── Sandbox dependencies ─────────────────────────────────────────────────────

# bubblewrap (bwrap) — extracted from .deb, no sudo
if command -v bwrap &>/dev/null; then
    echo "[ok] bwrap already installed: $(bwrap --version)"
else
    echo "[..] Installing bwrap from .deb..."
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        apt download bubblewrap 2>/dev/null
        mkdir extract
        dpkg -x bubblewrap_*.deb extract
        cp extract/usr/bin/bwrap "$HOME/.local/bin/bwrap"
        chmod +x "$HOME/.local/bin/bwrap"
    )
    rm -rf "$tmpdir"
    echo "[ok] bwrap installed: $(bwrap --version)"
fi

# mitmproxy (optional, for --proxy flag)
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

# Generate mitmproxy CA certs
if command -v mitmdump &>/dev/null && [[ ! -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]]; then
    echo "[..] Generating mitmproxy CA certificates..."
    timeout 3 mitmdump --listen-host 127.0.0.1 --listen-port 18099 &>/dev/null || true
    echo "[ok] CA certs generated in ~/.mitmproxy/"
fi

# Combined CA bundle
if [[ -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]]; then
    SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
    if [[ -f "$SYSTEM_CA" ]]; then
        cat "$SYSTEM_CA" "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" > "$HOME/.mitmproxy/combined-ca.pem"
        echo "[ok] Combined CA bundle created"
    else
        echo "[warn] System CA bundle not found at $SYSTEM_CA — skip combined CA"
    fi
fi

# ── Zsh plugins ───────────────────────────────────────────────────────────────

# zinit
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ -d "$ZINIT_HOME" ]]; then
    echo "[ok] zinit already installed"
else
    echo "[..] Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    echo "[ok] zinit installed"
fi

# ── SSH & credentials ─────────────────────────────────────────────────────────

# Pre-populate SSH known_hosts
echo "[..] Adding GitHub/GitLab to known_hosts..."
mkdir -p "$HOME/.ssh"
ssh-keyscan github.com gitlab.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo "[ok] known_hosts updated"

# Create credentials.json from example if missing
CRED_FILE="$HOME/.config/proxy-creds/credentials.json"
CRED_EXAMPLE="$HOME/.config/proxy-creds/credentials.json.example"
if [[ ! -f "$CRED_FILE" ]] && [[ -f "$CRED_EXAMPLE" ]]; then
    cp "$CRED_EXAMPLE" "$CRED_FILE"
    echo "[ok] Created $CRED_FILE from example — edit it with your real tokens"
elif [[ -f "$CRED_FILE" ]]; then
    echo "[ok] $CRED_FILE already exists"
fi

# ── Default shell ─────────────────────────────────────────────────────────────

ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
if [[ -n "$ZSH_PATH" && "$SHELL" != *"zsh"* ]]; then
    if chsh -s "$ZSH_PATH" 2>/dev/null; then
        echo "[ok] Default shell set to $ZSH_PATH"
    else
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
elif [[ -n "$ZSH_PATH" ]]; then
    echo "[ok] Default shell is already zsh"
else
    echo "[warn] zsh not found. Install it first (apt install zsh / brew install zsh)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Done ==="
echo ""
echo "Installed tools:"
for cmd in rg fd fzf jq nvim vifm jj uv claude bwrap mitmdump; do
    if command -v "$cmd" &>/dev/null; then
        printf "  %-12s %s\n" "$cmd" "$("$cmd" --version 2>&1 | head -1)"
    else
        printf "  %-12s %s\n" "$cmd" "(not installed)"
    fi
done
echo ""
echo "Run 'p10k configure' to set up your prompt style."
echo "Edit ~/.config/proxy-creds/credentials.json for --proxy mode."
