# .zshenv — sourced for ALL zsh invocations (login, interactive, scripts)
# Keep this minimal — only env vars and PATH.

# Cargo/Rust
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# Local binaries
export PATH="$HOME/.local/bin:$PATH"
