# .zshenv — sourced for ALL zsh invocations (login, interactive, scripts)
# Keep this minimal — only env vars and PATH.

# Cargo/Rust
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# User
export USER="${USER:-$(whoami)}"

# PATH
typeset -U path  # deduplicate
path=(
    "$HOME/.local/bin"
    "$HOME/.local/gcc-11/bin"
    "$HOME/ripgrep-14.1.0-x86_64-unknown-linux-musl"
    "$HOME/fd-v10.1.0-x86_64-unknown-linux-musl"
    "$HOME/nvim-linux64/bin"
    "$HOME"
    $path
)

# gcc-11 runtime libs (needed by uv and other tools)
export LD_LIBRARY_PATH="$HOME/.local/gcc-11/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Timezone
export TZ="Asia/Yerevan"

# pcpctl
export PCPCTL_CREDENTIALS_BACKEND="plain"

# HuggingFace cache
export HF_HOME="/weka/teams/gte/huggingface/hub"
export HF_HUB_CACHE="$HF_HOME"
