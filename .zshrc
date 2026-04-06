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

# Enable Powerlevel10k instant prompt (must be near top of .zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load p10k config if it exists
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ── Fish-like plugins ─────────────────────────────────────────────────────────

# Inline grey suggestions from history (accept with →)
zinit light zsh-users/zsh-autosuggestions

# Fish-like history substring search (type partial command, press ↑/↓)
zinit light zsh-users/zsh-history-substring-search

# Syntax highlighting (like fish)
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

# History substring search with Up/Down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

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

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select

# ── fzf integration ───────────────────────────────────────────────────────────

if command -v fzf &>/dev/null; then
    # fzf keybindings (Ctrl+R for history, Ctrl+T for files)
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
fi

# ── PATH additions ────────────────────────────────────────────────────────────

# User tools (same paths as claude-sandbox)
typeset -U path  # deduplicate
path=(
    "$HOME/.local/bin"
    "$HOME/.local/gcc-11/bin"
    "$HOME/ripgrep-14.1.0-x86_64-unknown-linux-musl"
    "$HOME/fd-v10.1.0-x86_64-unknown-linux-musl"
    "$HOME/nvim-linux64/bin"
    "$HOME/yazi-x86_64-unknown-linux-musl"
    "$HOME/go/bin"
    $path
)

# ── Aliases ───────────────────────────────────────────────────────────────────

alias v='nvim'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

# jj (jujutsu) shortcuts
alias jl='jj log'
alias jd='jj diff'
alias js='jj status'

# ── Local overrides ───────────────────────────────────────────────────────────

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
