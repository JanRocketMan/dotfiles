# .zshenv — sourced for ALL zsh invocations (login, interactive, scripts)
# Keep this minimal — only env vars and PATH.

# Cargo/Rust
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# User
export USER="${USER:-$(whoami)}"

# Local binaries
export PATH="$HOME/.local/bin:$PATH"

# gcc-11 runtime libs (needed by uv and other tools)
export LD_LIBRARY_PATH="$HOME/.local/gcc-11/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# HuggingFace cache
export HF_HOME="/weka/teams/gte/huggingface/hub"
export HF_HUB_CACHE="$HF_HOME"
