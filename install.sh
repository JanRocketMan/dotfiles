#!/usr/bin/env bash
set -euo pipefail

# install.sh — Bootstrap dotfiles dependencies on a new machine.
# Run AFTER `stow .` has symlinked everything into place.
#
# Supports Linux (x86_64, aarch64) and macOS (arm64, x86_64).
# All tools are installed to ~/.local/bin/ (no sudo required).

mkdir -p "$HOME/.local/bin"

# ── Platform detection ────────────────────────────────────────────────────────

ARCH="$(uname -m)"
OS_RAW="$(uname -s)"

case "$OS_RAW" in
    Linux)  OS="linux"  ;;
    Darwin) OS="darwin" ;;
    *)      echo "error: unsupported OS: $OS_RAW" >&2; exit 1 ;;
esac

# Arch aliases used by different projects
case "$ARCH" in
    x86_64)
        ARCH_ALT="amd64"           # fzf, jq
        RUST_TARGET_LINUX="x86_64-unknown-linux-musl"
        RUST_TARGET_DARWIN="x86_64-apple-darwin"
        NVIM_PLATFORM_LINUX="linux-x86_64"
        NVIM_PLATFORM_DARWIN="macos-x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ARCH_ALT="arm64"
        RUST_TARGET_LINUX="aarch64-unknown-linux-musl"
        RUST_TARGET_DARWIN="aarch64-apple-darwin"
        NVIM_PLATFORM_LINUX="linux-arm64"
        NVIM_PLATFORM_DARWIN="macos-arm64"
        ;;
    *)
        echo "error: unsupported architecture: $ARCH" >&2; exit 1
        ;;
esac

# Select the right target triple for Rust-built tools (rg, fd, jj)
if [[ "$OS" == "linux" ]]; then
    RUST_TARGET="$RUST_TARGET_LINUX"
    NVIM_PLATFORM="$NVIM_PLATFORM_LINUX"
else
    RUST_TARGET="$RUST_TARGET_DARWIN"
    NVIM_PLATFORM="$NVIM_PLATFORM_DARWIN"
fi

echo "=== Installing dotfiles dependencies ==="
echo "Platform: $OS / $ARCH"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

# Install a tool from a GitHub release tarball
# Usage: gh_install NAME VERSION URL [BINARY_PATH]
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

# ── CLI tools ─────────────────────────────────────────────────────────────────

# ripgrep
RG_VERSION="14.1.0"
gh_install rg "$RG_VERSION" \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${RUST_TARGET}.tar.gz" \
    "ripgrep-${RG_VERSION}-${RUST_TARGET}/rg"

# fd
FD_VERSION="10.1.0"
gh_install fd "$FD_VERSION" \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${RUST_TARGET}.tar.gz" \
    "fd-v${FD_VERSION}-${RUST_TARGET}/fd"

# fzf
FZF_VERSION="0.62.0"
gh_install fzf "$FZF_VERSION" \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${OS}_${ARCH_ALT}.tar.gz" \
    "fzf"

# jq (single binary, not tarball)
JQ_VERSION="1.7.1"
if command -v jq &>/dev/null; then
    echo "[ok] jq already installed: $(jq --version 2>&1)"
else
    echo "[..] Installing jq $JQ_VERSION..."
    JQ_OS="$OS"
    [[ "$OS" == "darwin" ]] && JQ_OS="macos"
    wget -q "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${JQ_OS}-${ARCH_ALT}" \
        -O "$HOME/.local/bin/jq"
    chmod +x "$HOME/.local/bin/jq"
    echo "[ok] jq installed: $(jq --version 2>&1)"
fi

# ── Editors & file managers ───────────────────────────────────────────────────

# Neovim (extracts as a directory tree with bin/, lib/, share/)
NVIM_VERSION="0.10.3"
if command -v nvim &>/dev/null; then
    echo "[ok] nvim already installed: $(nvim --version 2>&1 | head -1)"
else
    echo "[..] Installing nvim $NVIM_VERSION..."
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        wget -q "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-${NVIM_PLATFORM}.tar.gz" \
            -O nvim.tar.gz
        tar xzf nvim.tar.gz
        rm -rf "$HOME/nvim-linux64"
        mv nvim-${NVIM_PLATFORM} "$HOME/nvim-linux64"
    )
    rm -rf "$tmpdir"
    echo "[ok] nvim installed: $(nvim --version 2>&1 | head -1)"
fi

# vifm (Linux: GitHub release tarball; macOS: brew)
VIFM_VERSION="0.14"
if command -v vifm &>/dev/null; then
    echo "[ok] vifm already installed: $(vifm --version 2>&1 | head -1)"
else
    if [[ "$OS" == "linux" ]]; then
        gh_install vifm "$VIFM_VERSION" \
            "https://github.com/vifm/vifm/releases/download/v${VIFM_VERSION}/vifm-v${VIFM_VERSION}-${ARCH}.tar.gz" \
            "vifm-v${VIFM_VERSION}-${ARCH}/vifm"
    else
        if command -v brew &>/dev/null; then
            echo "[..] Installing vifm via brew..."
            brew install vifm
            echo "[ok] vifm installed"
        else
            echo "[skip] vifm: no Linux binary for macOS and brew not found"
        fi
    fi
fi

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
        wget -q "https://github.com/jj-vcs/jj/releases/download/v${JJ_VERSION}/jj-v${JJ_VERSION}-${RUST_TARGET}.tar.gz" \
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
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        echo "[ok] claude installed: $(command claude --version 2>&1 | head -1)"
    else
        echo "[skip] Claude Code requires npm. Install Node.js first, then: npm install -g @anthropic-ai/claude-code"
    fi
fi

# ── Sandbox dependencies (Linux only) ────────────────────────────────────────

if [[ "$OS" == "linux" ]]; then
    # bubblewrap — extracted from .deb, no sudo
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
else
    echo "[skip] bwrap: Linux only (macOS uses sandbox-exec)"
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
        echo "[skip] mitmproxy: uv not found. Install manually for --proxy support."
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
    # System CA bundle location differs by OS
    if [[ "$OS" == "linux" ]]; then
        SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
    else
        SYSTEM_CA="/etc/ssl/cert.pem"
    fi
    if [[ -f "$SYSTEM_CA" ]]; then
        cat "$SYSTEM_CA" "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" > "$HOME/.mitmproxy/combined-ca.pem"
        echo "[ok] Combined CA bundle created"
    else
        echo "[warn] System CA bundle not found at $SYSTEM_CA — skip combined CA"
    fi
fi

# ── Zsh plugins ───────────────────────────────────────────────────────────────

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

echo "[..] Adding GitHub/GitLab to known_hosts..."
mkdir -p "$HOME/.ssh"
ssh-keyscan github.com gitlab.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo "[ok] known_hosts updated"

CRED_FILE="$HOME/.config/proxy-creds/credentials.json"
CRED_EXAMPLE="$HOME/.config/proxy-creds/credentials.json.example"
if [[ ! -f "$CRED_FILE" ]] && [[ -f "$CRED_EXAMPLE" ]]; then
    mkdir -p "$(dirname "$CRED_FILE")"
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
