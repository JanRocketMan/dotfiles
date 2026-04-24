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

# ── Shell ─────────────────────────────────────────────────────────────────────

# zsh: extract from system .deb so it's available on compute nodes via shared $HOME
if [[ -x "$HOME/.local/bin/zsh" ]]; then
    echo "[ok] zsh (local) already installed: $("$HOME/.local/bin/zsh" --version 2>&1)"
else
    echo "[..] Installing zsh (local copy)..."
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        apt download zsh zsh-common 2>/dev/null
        mkdir extract
        for f in *.deb; do dpkg -x "$f" extract; done
        cp extract/bin/zsh "$HOME/.local/bin/zsh"
        chmod +x "$HOME/.local/bin/zsh"
        # modules (.so files) and functions needed on compute nodes
        rm -rf "$HOME/.local/lib/zsh" "$HOME/.local/share/zsh"
        mkdir -p "$HOME/.local/lib" "$HOME/.local/share"
        cp -r extract/usr/lib/x86_64-linux-gnu/zsh "$HOME/.local/lib/zsh"
        cp -r extract/usr/share/zsh "$HOME/.local/share/zsh"
    )
    rm -rf "$tmpdir"
    echo "[ok] zsh (local) installed: $("$HOME/.local/bin/zsh" --version 2>&1)"
fi

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
install_tarball glab

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
if [[ "$method" == "source" ]]; then
    if command -v bwrap &>/dev/null; then
        echo "[ok] bwrap already installed: $(bwrap --version)"
    else
        url="$(manifest_get bwrap url)"
        echo "[..] Building bwrap from source..."
        for dep in meson ninja pkg-config; do
            if ! command -v "$dep" &>/dev/null; then
                echo "[skip] bwrap: missing build dependency '$dep'" >&2
                echo "       install with: uv tool install $dep" >&2
                url=""
                break
            fi
        done
        if [[ -n "$url" ]]; then
            tmpdir="$(mktemp -d)"
            (
                cd "$tmpdir"
                # fetch libcap-dev headers if not installed
                if ! pkg-config --exists libcap 2>/dev/null; then
                    apt download libcap-dev 2>/dev/null
                    mkdir -p libcap-staging
                    dpkg -x libcap-dev_*.deb libcap-staging
                    local_prefix="$tmpdir/libcap-staging/usr"
                    export PKG_CONFIG_PATH="$local_prefix/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
                    export CFLAGS="-I$local_prefix/include"
                    export LDFLAGS="-L$local_prefix/lib/x86_64-linux-gnu"
                fi
                wget -q "$url" -O src.tar.xz
                tar xf src.tar.xz
                cd bubblewrap-*/
                meson setup _build -Dselinux=disabled -Dtests=false 2>&1 | tail -1
                ninja -C _build 2>&1 | tail -1
                cp _build/bwrap "$HOME/.local/bin/bwrap"
                chmod +x "$HOME/.local/bin/bwrap"
            )
            rm -rf "$tmpdir"
            echo "[ok] bwrap installed: $(bwrap --version)"
        fi
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

# ── macOS defaults ───────────────────────────────────────────────────────────

if [[ "$OS" == "darwin" ]]; then
    echo "[..] Applying macOS defaults..."
    bash "$SCRIPT_DIR/macos-defaults.sh"
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

# ── Nanobox (agent sandbox) ──────────────────────────────────────────────────

NANOBOX_DIR="$HOME/nanobox"
if [[ -d "$NANOBOX_DIR" ]]; then
    echo "[ok] nanobox already cloned: $NANOBOX_DIR"
else
    echo "[..] Cloning nanobox..."
    git clone https://github.com/JanRocketMan/nanobox.git "$NANOBOX_DIR"
    echo "[ok] nanobox cloned"
fi

CRED_TEMPLATE="$HOME/.config/nanobox/credentials.template.json"
if [[ -f "$CRED_TEMPLATE" ]]; then
    echo "[ok] Credential template exists: $CRED_TEMPLATE"
    echo "     Run 'nbox resolve' to generate credentials.json from env vars"
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
    if timeout 5 chsh -s "$ZSH_PATH" </dev/null 2>/dev/null; then
        echo "[ok] Default shell set to $ZSH_PATH"
    else
        PROFILE="$HOME/.bash_profile"
        EXEC_LINE='[[ -x "$HOME/.local/bin/zsh" && -z $ZSH_VERSION ]] && exec "$HOME/.local/bin/zsh" -l'
        if ! grep -qF 'exec "$HOME/.local/bin/zsh"' "$PROFILE" 2>/dev/null; then
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
for cmd in rg fd fzf jq zsh nvim vifm jj glab uv claude bwrap mitmdump; do
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
echo "  nbox setup                                  # configure sandbox (edit config.yaml)"
echo "  nbox resolve                                # generate credentials.json from env"
if command -v srun &>/dev/null; then
    echo "  Edit ~/.config/slurm/cluster.conf           # partition names for this cluster"
fi
