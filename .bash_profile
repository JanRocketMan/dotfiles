
# Auto-switch to zsh on login (no sudo for chsh).
# Prefer the locally-installed zsh (compute nodes without system zsh),
# fall back to the system one. CRITICAL: preserve -c commands so a
# `bash -c "..."` (e.g. Claude Code's ! shell escape, or any tool that
# shells out) runs the command instead of dropping into an interactive
# shell and hanging forever.
if [[ -z $ZSH_VERSION ]]; then
    for _zsh in "$HOME/.local/bin/zsh" /usr/bin/zsh; do
        [[ -x "$_zsh" ]] || continue
        if [[ -n "$BASH_EXECUTION_STRING" ]]; then
            exec "$_zsh" -c "$BASH_EXECUTION_STRING"
        elif [[ $- == *i* ]]; then
            exec "$_zsh" -l
        fi
        break  # non-interactive, no command (e.g. `bash script.sh`): stay in bash
    done
    unset _zsh
fi

. "$HOME/.local/bin/env"
