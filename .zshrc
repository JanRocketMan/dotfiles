# .zshrc — sourced for interactive shells only

# ── Source .bashrc for env setup (SLURM, modules, etc.) ──────────────────────

# Many systems put important config in .bashrc (module loads, SLURM paths,
# conda init, etc.). Source it in emulate-sh mode so bash-only builtins
# (shopt, bind, etc.) are silently ignored instead of erroring.
# Set ZSH_SOURCING_BASHRC so .bashrc can skip shell-switching lines.
if [[ -f "$HOME/.bashrc" ]]; then
    ZSH_SOURCING_BASHRC=1 emulate sh -c 'source "$HOME/.bashrc"' 2>/dev/null
fi

# ── Zinit plugin manager ──────────────────────────────────────────────────────

ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ── Prompt: Powerlevel10k ─────────────────────────────────────────────────────

zinit ice depth=1
zinit light romkatv/powerlevel10k

# Load p10k config if it exists
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ── Fish-like plugins (turbo-loaded: deferred until after first prompt) ───────

# Inline grey suggestions from history (accept with →)
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions

# Fish-like history substring search (type partial command, press ↑/↓)
# atload: bind Up/Down after the plugin is available
zinit ice wait lucid atload'bindkey "^[[A" history-substring-search-up; bindkey "^[[B" history-substring-search-down'
zinit light zsh-users/zsh-history-substring-search

# Syntax highlighting (like fish)
# atload: set highlight colors after the plugin is available
zinit ice wait lucid atload'
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]="fg=blue"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=blue"
ZSH_HIGHLIGHT_STYLES[alias]="fg=blue"
ZSH_HIGHLIGHT_STYLES[function]="fg=blue"
ZSH_HIGHLIGHT_STYLES[precommand]="fg=blue,underline"
ZSH_HIGHLIGHT_STYLES[path]="fg=cyan,underline"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=red"
'
zinit light zsh-users/zsh-syntax-highlighting

# ── History ───────────────────────────────────────────────────────────────────

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Key bindings ──────────────────────────────────────────────────────────────

# (Up/Down for history-substring-search are bound in the plugin's atload above)

# Ctrl+Arrow word navigation
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Home/End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line

# Delete key
bindkey '^[[3~' delete-char

# ── Completion ────────────────────────────────────────────────────────────────

# Rebuild .zcompdump at most once a day; otherwise load cached
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select

# ── fzf integration ───────────────────────────────────────────────────────────

if command -v fzf &>/dev/null; then
    # fzf keybindings (Ctrl+R for history, Ctrl+T for files)
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
fi

# Prevent venv activate from modifying PS1 (p10k handles the prompt)
export VIRTUAL_ENV_DISABLE_PROMPT=1
export EDITOR='nvim -u ~/.config/nvim/lua/init.lua'
export VISUAL='nvim -u ~/.config/nvim/lua/init.lua'

# ── Auto-activate .venv on directory entry ────────────────────────────────────

_auto_venv() {
    # Deactivate if we left the venv's project
    if [[ -n "$VIRTUAL_ENV" && ! "$PWD" == "${VIRTUAL_ENV%/.venv*}"* ]]; then
        if (( $+functions[deactivate] )); then
            deactivate
        else
            unset VIRTUAL_ENV
        fi
    fi
    # Activate if cwd has a .venv
    if [[ -z "$VIRTUAL_ENV" && -f .venv/bin/activate ]]; then
        source .venv/bin/activate
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_venv
_auto_venv  # run once on shell start

# ── Aliases ───────────────────────────────────────────────────────────────────

[[ -f ~/.aliases ]] && source ~/.aliases

# ── Local overrides ───────────────────────────────────────────────────────────

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
