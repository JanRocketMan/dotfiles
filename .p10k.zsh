# Powerlevel10k config — fish-like single-line prompt
# Style: user@host ~/q/src ((commit))>

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    virtualenv context dir my_vcs
  )
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

  # ── Lean mode: no backgrounds, no padding ────────────────────────────────

  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

  # The > prompt is baked into the last segment's end symbol
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='%(?::%F{red} [%?]%f)%F{green}❯%f'

  # ── context (user@host) ─────────────────────────────────────────────────

  # Fish colors: green user, yellow host
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%F{green}%n%f@%F{yellow}%m%f'
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,REMOTE}_FOREGROUND=default
  typeset -g POWERLEVEL9K_CONTEXT_{SUDO,REMOTE_SUDO,ROOT}_FOREGROUND=red

  # ── dir (current directory) ──────────────────────────────────────────────

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=green
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_from_right
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=false
  # No folder icons
  typeset -g POWERLEVEL9K_DIR_ETC_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_DIR_HOME_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_DIR_HOME_SUBFOLDER_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_DIR_DEFAULT_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_VISUAL_IDENTIFIER_EXPANSION=

  # ── my_vcs (jj preferred, git fallback) ──────────────────────────────────

  typeset -g POWERLEVEL9K_MY_VCS_FOREGROUND=default
  typeset -g POWERLEVEL9K_MY_VCS_VISUAL_IDENTIFIER_EXPANSION=

  function prompt_my_vcs() {
    # Try jj first
    if command -v jj &>/dev/null && jj root &>/dev/null; then
      local branch
      branch="$(jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)"
      if [[ -z "$branch" ]]; then
        # No bookmark on @ — check parent
        branch="$(jj log -r @- --no-graph -T 'bookmarks.map(|b| b.name()).join(", ")' 2>/dev/null)"
      fi
      [[ -n "$branch" ]] && p10k segment -f default -t "on ${branch}"
      return
    fi
    # Fall back to git
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
      local branch
      branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
      [[ -n "$branch" ]] && p10k segment -f default -t "on ${branch}"
    fi
  }

  # ── virtualenv ────────────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=default
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=false
  typeset -g POWERLEVEL9K_VIRTUALENV_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER='('
  typeset -g POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER=')'
  # Show only the venv directory name, not the full path
  typeset -g POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES=()
  typeset -g POWERLEVEL9K_VIRTUALENV_{PYENV_PROMPT,PYENV_PREFIX}=

  # ── Misc ─────────────────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
