#!/usr/bin/env bash
set -euo pipefail

# install.sh — Bootstrap dotfiles dependencies on a new machine.
# Run AFTER `stow .` has symlinked everything into place.
#
# All download URLs come from TOOLS.md — the single source of truth
# for external dependencies. If a tool is compromised, edit that file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/TOOLS.md"

if [[ ! -f "$MANIFEST" ]]; then
    echo "error: TOOLS.md not found at $MANIFEST" >&2
    exit 1
fi

mkdir -p "$HOME/.local/bin"

# ── Platform detection ────────────────────────────────────────────────────────

ARCH="$(uname -m)"
OS_RAW="$(uname -s)"

case "$OS_RAW" in
    Linux)  OS="linux"  ;;
    Darwin) OS="darwin" ;;
    *)      echo "error: unsupported OS: $OS_RAW" >&2; exit 1 ;;
esac

case "$ARCH" in
    x86_64)          ARCH="x86_64"  ;;
    aarch64|arm64)   ARCH="aarch64" ;;
    *)               echo "error: unsupported arch: $ARCH" >&2; exit 1 ;;
esac

PLATFORM="${OS}-${ARCH}"

echo "=== Installing dotfiles dependencies ==="
echo "Platform: $PLATFORM"
echo "Manifest: $MANIFEST"
echo ""

# ── Manifest lookup ───────────────────────────────────────────────────────────

# Look up a field from TOOLS.md for a given tool and platform.
# Falls back to "all" platform if exact match not found.
# Usage: manifest_get TOOL FIELD
#   FIELD: url (col 5), binary (col 6), method (col 7)
manifest_get() {
    local tool="$1" field="$2"
    local col
    case "$field" in
        url)    col=5 ;;
        binary) col=6 ;;
        method) col=7 ;;
        *)      echo "error: unknown field: $field" >&2; return 1 ;;
    esac

    # Try exact platform, then OS-all, then all
    local result
    for try_plat in "$PLATFORM" "${OS}-all" "all"; do
        result=$(awk -F'|' -v tool=" $tool " -v plat=" $try_plat " \
            'NR>2 && $2 ~ tool && $4 ~ plat {
                val = $'$col'
                gsub(/^[ `]+|[ `]+$/, "", val)
                print val
                exit
            }' "$MANIFEST")
        if [[ -n "$result" && "$result" != "-" ]]; then
            echo "$result"
            return 0
        fi
    done
    echo ""
}

# ── Install helpers ───────────────────────────────────────────────────────────

# Install from tarball: download, extract, copy binary to ~/.local/bin
install_tarball() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        echo "[ok] $name already installed: $("$name" --version 2>&1 | head -1)"
        return
    fi
    local url bin_path
    url="$(manifest_get "$name" url)"
    bin_path="$(manifest_get "$name" binary)"
    if [[ -z "$url" ]]; then
        echo "[skip] $name: no URL for $PLATFORM"
        return
    fi
    echo "[..] Installing $name..."
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

# Install a raw binary (no archive)
install_binary() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        echo "[ok] $name already installed: $("$name" --version 2>&1 | head -1)"
        return
    fi
    local url
    url="$(manifest_get "$name" url)"
    if [[ -z "$url" ]]; then
        echo "[skip] $name: no URL for $PLATFORM"
        return
    fi
    echo "[..] Installing $name..."
    wget -q "$url" -O "$HOME/.local/bin/$name"
    chmod +x "$HOME/.local/bin/$name"
    echo "[ok] $name installed: $("$name" --version 2>&1 | head -1)"
}

# ── CLI tools ─────────────────────────────────────────────────────────────────

install_tarball rg
install_tarball fd
install_tarball fzf
install_binary jq

# ── Editors & file managers ───────────────────────────────────────────────────

# Neovim: tarball-tree (directory with bin/, lib/, share/)
if command -v nvim &>/dev/null; then
    echo "[ok] nvim already installed: $(nvim --version 2>&1 | head -1)"
else
    url="$(manifest_get nvim url)"
    bin_path="$(manifest_get nvim binary)"
    if [[ -n "$url" ]]; then
        echo "[..] Installing nvim..."
        tmpdir="$(mktemp -d)"
        (
            cd "$tmpdir"
            wget -q "$url" -O nvim.tar.gz
            tar xzf nvim.tar.gz
            rm -rf "$HOME/nvim-linux64"
            mv "$bin_path" "$HOME/nvim-linux64"
        )
        rm -rf "$tmpdir"
        echo "[ok] nvim installed: $(nvim --version 2>&1 | head -1)"
    else
        echo "[skip] nvim: no URL for $PLATFORM"
    fi
fi

# vifm: AppImage on Linux x86_64, brew on macOS / Linux aarch64
if command -v vifm &>/dev/null; then
    echo "[ok] vifm already installed: $(vifm --version 2>&1 | head -1)"
else
    method="$(manifest_get vifm method)"
    if [[ "$method" == "appimage" ]]; then
        url="$(manifest_get vifm url)"
        echo "[..] Installing vifm (AppImage)..."
        wget -q "$url" -O "$HOME/.local/bin/vifm"
        chmod +x "$HOME/.local/bin/vifm"
        echo "[ok] vifm installed: $(vifm --version 2>&1 | head -1)"
    elif [[ "$method" == "brew" ]]; then
        if command -v brew &>/dev/null; then
            echo "[..] Installing vifm via brew..."
            brew install vifm
            echo "[ok] vifm installed"
        else
            echo "[skip] vifm: brew not found"
        fi
    else
        echo "[skip] vifm: no install method for $PLATFORM"
    fi
fi

# ── VCS ───────────────────────────────────────────────────────────────────────

install_tarball jj

# ── Python tooling ────────────────────────────────────────────────────────────

if command -v uv &>/dev/null; then
    echo "[ok] uv already installed: $(uv --version 2>&1)"
else
    url="$(manifest_get uv url)"
    echo "[..] Installing uv..."
    curl -LsSf "$url" | sh
    echo "[ok] uv installed"
fi

# ── Claude Code ───────────────────────────────────────────────────────────────

if command -v claude &>/dev/null 2>&1; then
    echo "[ok] claude already installed: $(command claude --version 2>&1 | head -1)"
else
    method="$(manifest_get claude method)"
    if [[ "$method" == "npm" ]]; then
        pkg="$(manifest_get claude url)"
        pkg="${pkg#npm:}"  # strip npm: prefix
        if command -v npm &>/dev/null; then
            echo "[..] Installing Claude Code..."
            npm install -g "$pkg"
            echo "[ok] claude installed"
        else
            echo "[skip] Claude Code requires npm. Install Node.js first, then: npm install -g $pkg"
        fi
    fi
fi

# ── Sandbox dependencies ─────────────────────────────────────────────────────

# bubblewrap (Linux only, from .deb)
method="$(manifest_get bwrap method)"
if [[ "$method" == "deb" ]]; then
    if command -v bwrap &>/dev/null; then
        echo "[ok] bwrap already installed: $(bwrap --version)"
    else
        pkg="$(manifest_get bwrap url)"
        pkg="${pkg#apt:}"  # strip apt: prefix
        echo "[..] Installing bwrap from .deb..."
        tmpdir="$(mktemp -d)"
        (
            cd "$tmpdir"
            apt download "$pkg" 2>/dev/null
            mkdir extract
            dpkg -x "${pkg}"_*.deb extract
            cp extract/usr/bin/bwrap "$HOME/.local/bin/bwrap"
            chmod +x "$HOME/.local/bin/bwrap"
        )
        rm -rf "$tmpdir"
        echo "[ok] bwrap installed: $(bwrap --version)"
    fi
else
    echo "[skip] bwrap: Linux only (macOS uses sandbox-exec)"
fi

# mitmproxy (via uv tool)
if command -v mitmdump &>/dev/null; then
    echo "[ok] mitmdump already installed: $(mitmdump --version 2>&1 | head -1)"
else
    method="$(manifest_get mitmproxy method)"
    if [[ "$method" == "uv-tool" ]] && command -v uv &>/dev/null; then
        pkg="$(manifest_get mitmproxy url)"
        pkg="${pkg#uv-tool:}"
        echo "[..] Installing mitmproxy via uv..."
        uv tool install "$pkg"
        echo "[ok] mitmdump installed"
    else
        echo "[skip] mitmproxy: uv not found"
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
    if [[ "$OS" == "linux" ]]; then
        SYSTEM_CA="/etc/ssl/certs/ca-certificates.crt"
    else
        SYSTEM_CA="/etc/ssl/cert.pem"
    fi
    if [[ -f "$SYSTEM_CA" ]]; then
        cat "$SYSTEM_CA" "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" > "$HOME/.mitmproxy/combined-ca.pem"
        echo "[ok] Combined CA bundle created"
    else
        echo "[warn] System CA bundle not found at $SYSTEM_CA"
    fi
fi

# ── Zsh plugins ───────────────────────────────────────────────────────────────

ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ -d "$ZINIT_HOME" ]]; then
    echo "[ok] zinit already installed"
else
    url="$(manifest_get zinit url)"
    echo "[..] Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone "$url" "$ZINIT_HOME"
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
    echo "[ok] Created $CRED_FILE from example"
elif [[ -f "$CRED_FILE" ]]; then
    echo "[ok] $CRED_FILE already exists"
fi

# Create cluster.conf from example if missing
CLUSTER_CONF="$HOME/.config/slurm/cluster.conf"
CLUSTER_EXAMPLE="$HOME/.config/slurm/cluster.conf.example"
if [[ ! -f "$CLUSTER_CONF" ]] && [[ -f "$CLUSTER_EXAMPLE" ]]; then
    mkdir -p "$(dirname "$CLUSTER_CONF")"
    cp "$CLUSTER_EXAMPLE" "$CLUSTER_CONF"
    echo "[ok] Created $CLUSTER_CONF from example — edit partition names for this cluster"
elif [[ -f "$CLUSTER_CONF" ]]; then
    echo "[ok] $CLUSTER_CONF already exists"
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
            echo "[ok] Added zsh exec to $PROFILE"
        else
            echo "[ok] $PROFILE already execs zsh"
        fi
    fi
elif [[ -n "$ZSH_PATH" ]]; then
    echo "[ok] Default shell is already zsh"
else
    echo "[warn] zsh not found (apt install zsh / brew install zsh)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Done ==="
echo ""
echo "Installed tools:"
for cmd in rg fd fzf jq nvim vifm jj uv claude bwrap mitmdump; do
    if command -v "$cmd" &>/dev/null; then
        ver="$(timeout 5 "$cmd" --version 2>&1 | head -1)" || ver="(installed)"
        printf "  %-12s %s\n" "$cmd" "$ver"
    else
        printf "  %-12s %s\n" "$cmd" "(not installed)"
    fi
done
echo ""
echo "Next steps:"
echo "  p10k configure                              # set up prompt style"
echo "  Edit ~/.config/proxy-creds/credentials.json # API tokens for --proxy mode"
if command -v srun &>/dev/null; then
    echo "  Edit ~/.config/slurm/cluster.conf           # partition names for this cluster"
fi
