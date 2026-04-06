#!/bin/bash

# Neovim Configuration Installation Script
# This script installs Neovim with frozen.nvim configuration

set -e  # Exit on any error

# Check for min option
MIN_MODE=false
if [[ "$1" == "min" ]]; then
    MIN_MODE=true
    echo "⚠️ Running in minimal mode - will download only ilua/init.lua with no plugins"
fi

echo "🚀 Starting Neovim configuration installation..."

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos-arm"
    NVIM_URL="https://github.com/neovim/neovim/releases/download/v0.10.0/nvim-macos-arm64.tar.gz"
    NVIM_DIR="nvim-macos-arm64"
    RIPGREP_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-aarch64-apple-darwin.tar.gz"
    RIPGREP_DIR="ripgrep-14.1.0-aarch64-apple-darwin"
    FD_URL="https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-aarch64-apple-darwin.tar.gz"
    FD_DIR="fd-v10.1.0-aarch64-apple-darwin"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    NVIM_URL="https://github.com/neovim/neovim/releases/download/v0.10.0/nvim-linux64.tar.gz"
    NVIM_DIR="nvim-linux64"
    RIPGREP_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz"
    RIPGREP_DIR="ripgrep-14.1.0-x86_64-unknown-linux-musl"
    FD_URL="https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz"
    FD_DIR="fd-v10.1.0-x86_64-unknown-linux-musl"
else
    echo "❌ Unsupported platform: $OSTYPE"
    exit 1
fi

echo "✅ Detected platform: $PLATFORM"

# Check for required system utilities
echo "🔍 Checking system requirements..."
for cmd in git make gcc unzip; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Required command '$cmd' not found. Please install it first."
        exit 1
    fi
done
echo "✅ All system requirements met"

# Install uv if not present
if ! command -v uv &> /dev/null; then
    echo "📥 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "✅ uv installed"
    # Source the shell profile to make uv available in current session
    if [[ -f "$HOME/.bashrc" ]]; then
        source "$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        source "$HOME/.zshrc"
    fi
else
    echo "✅ uv already installed"
fi

# Download and extract Neovim (only if not already present)
if [[ ! -d "$HOME/$NVIM_DIR" ]]; then
    echo "📥 Downloading Neovim..."
    cd ~
    curl -L -o nvim.tar.gz "$NVIM_URL"
    tar -xzf nvim.tar.gz
    rm nvim.tar.gz
    echo "✅ Neovim downloaded and extracted"
else
    echo "✅ Neovim already exists at ~/$NVIM_DIR"
fi

# Download and extract ripgrep (only if not already present)
if [[ ! -d "$HOME/$RIPGREP_DIR" ]]; then
    echo "📥 Downloading ripgrep..."
    cd ~
    curl -L -o ripgrep.tar.gz "$RIPGREP_URL"
    tar -xzf ripgrep.tar.gz
    rm ripgrep.tar.gz
    echo "✅ ripgrep downloaded and extracted"
else
    echo "✅ ripgrep already exists at ~/$RIPGREP_DIR"
fi

# Download and extract fd (only if not already present)
if [[ ! -d "$HOME/$FD_DIR" ]]; then
    echo "📥 Downloading fd..."
    cd ~
    curl -L -o fd.tar.gz "$FD_URL"
    tar -xzf fd.tar.gz
    rm fd.tar.gz
    echo "✅ fd downloaded and extracted"
else
    echo "✅ fd already exists at ~/$FD_DIR"
fi

# Clean up previous Neovim configurations
echo "🧹 Cleaning up previous Neovim configurations..."
rm -rf ~/.cache/nvim ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim
echo "✅ Previous configurations cleaned"

# Add tools to PATH and aliases in bashrc
echo "⚙️ Configuring bashrc..."
if ! grep -q "export PATH=~/$NVIM_DIR/bin:\$PATH" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Neovim configuration tools" >> ~/.bashrc
    echo "export PATH=~/$NVIM_DIR/bin:\$PATH" >> ~/.bashrc
    echo "export PATH=~/$RIPGREP_DIR:\$PATH" >> ~/.bashrc
    echo "export PATH=~/$FD_DIR:\$PATH" >> ~/.bashrc
    echo "✅ PATH updated in ~/.bashrc"
else
    echo "✅ PATH already configured in ~/.bashrc"
fi

# Add aliases if not already present
if ! grep -q "alias dpython=" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Development aliases" >> ~/.bashrc
    echo "# activate local env" >> ~/.bashrc
    echo "ac() {" >> ~/.bashrc
    echo "        for dir in \$(find . -maxdepth 1 -type d -name '.*'); do" >> ~/.bashrc
    echo "          if [ -f \"\$dir/pyvenv.cfg\" ]; then" >> ~/.bashrc
    echo "                  source \"\${dir}/bin/activate\"" >> ~/.bashrc
    echo "          fi" >> ~/.bashrc
    echo "        done" >> ~/.bashrc
    echo "}" >> ~/.bashrc
    echo "alias vim='nvim -u ~/.config/nvim/lua/init.lua'" >> ~/.bashrc
    echo "alias ta='tmux a'" >> ~/.bashrc
    echo "alias tn='tmux new'" >> ~/.bashrc
    echo "alias dpython='python -m debugpy --wait-for-client --listen'" >> ~/.bashrc
    echo "alias upi='uv pip install'" >> ~/.bashrc
    echo "alias upu='uv pip uninstall'" >> ~/.bashrc
    echo "✅ Aliases added to ~/.bashrc"
else
    echo "✅ Aliases already configured in ~/.bashrc"
fi

# Source bashrc to update current session
echo "🔄 Updating current session PATH and aliases..."
source ~/.bashrc

# Setup Neovim configuration based on mode
if [[ "$MIN_MODE" == "true" ]]; then
    echo "📦 Cloning up minimal frozen.nvim configuration..."
    mkdir -p ~/.config/nvim
    curl -L -o ~/.config/nvim/init.lua "https://raw.githubusercontent.com/JanRocketMan/frozen.nvim/refs/heads/main/lua/init.lua"
    echo "✅ Minimal configuration downloaded to ~/.config/nvim/init.lua"
else
    echo "📦 Cloning up full frozen.nvim configuration..."
    git clone https://github.com/JanRocketMan/frozen.nvim.git ~/.config/nvim
    echo "✅ Full configuration cloned"
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Run 'nvim' to start Neovim and install all packages"
echo "3. If dealing with python project, select or create some uv/pip env and install dependencies: upi pyright ruff debugpy"
echo ""
echo "🛠️ Available tools:"
echo "  - nvim: ~/$NVIM_DIR/bin/nvim"
echo "  - ripgrep: ~/$RIPGREP_DIR/rg"
echo "  - fd: ~/$FD_DIR/fd"
echo "  - uv: $(which uv 2>/dev/null || echo 'installed via install script')"
echo ""
echo "🛠️ Available aliases:"
echo "  - ac: activate local Python virtual environment"
echo "  - ta: tmux attach"
echo "  - tn: tmux new session"
echo "  - dpython: Python with debugpy for debugging"
echo "  - upi: uv pip install"
echo "  - vim: run nvim in minimal mode (no plugins, no treesitter) - suitable to large files"
echo ""
if [[ "$MIN_MODE" == "true" ]]; then
    echo "📄 Configuration mode: Minimal (init.lua only with no plugins)"
else
    echo "📄 Configuration mode: Full (complete frozen.nvim repository)"
fi
echo ""
echo "⚠️  Note: This configuration is optimized for Python development."
echo "   Support for other languages may require manual configuration."
