# .zshenv — sourced for ALL zsh invocations (login, interactive, scripts)
# Keep this minimal — only env vars and PATH.

# Skip the system-wide compinit in /etc/zsh/zshrc — it runs an uncached scan
# of $fpath which is extremely slow on shared/network filesystems (SLURM).
# Our .zshrc already handles compinit with a 24h cache.
skip_global_compinit=1

# Cargo/Rust
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# User
export USER="${USER:-$(whoami)}"

# Local zsh modules/functions for compute nodes without system zsh
if [[ -d "$HOME/.local/lib/zsh" ]]; then
    module_path=("$HOME/.local/lib/zsh/5.8" $module_path)
    fpath=("$HOME/.local/share/zsh/functions/"**/*(N/) $fpath)
fi

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

# 1 thread per worker — CPU side is I/O-bound, not compute-bound
export OMP_NUM_THREADS=1

# PyTorch cache directories — keep out of /tmp for persistence across SLURM jobs
export TORCHINDUCTOR_CACHE_DIR="$HOME/.cache/torch_inductor"
export TRITON_CACHE_DIR="$HOME/.cache/torch_triton"
export TORCH_EXTENSIONS_DIR="$HOME/.cache/torch_extensions"
export TORCH_HOME="$HOME/.cache/torch_hub"
