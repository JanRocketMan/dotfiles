
# Auto-switch to zsh on login (no sudo for chsh)
if [[ -x /usr/bin/zsh && -z $ZSH_VERSION ]]; then
    if [[ -n "$BASH_EXECUTION_STRING" ]]; then
        # Preserve -c commands (e.g. from Claude Code's ! shell escape)
        exec /usr/bin/zsh -c "$BASH_EXECUTION_STRING"
    else
        exec /usr/bin/zsh -l
    fi
fi

# Auto-switch to zsh on login (no sudo for chsh)
[[ -x "$HOME/.local/bin/zsh" && -z $ZSH_VERSION ]] && exec "$HOME/.local/bin/zsh" -l
