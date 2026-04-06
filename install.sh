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

echo ""
echo "=== Done ==="
echo ""
echo "Usage:"
echo "  claude-sandbox ~/myproject              # basic sandbox"
echo "  claude-sandbox --proxy ~/myproject       # with credential injection"
echo "  claude-sandbox --shell ~/myproject       # debug with bash"
echo "  vifm                                     # file manager"
echo ""
echo "Edit ~/.config/proxy-creds/credentials.json to add your API tokens for --proxy mode."
