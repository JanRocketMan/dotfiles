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
    context dir vcs
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
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='%(?:%F{green}❯%f:%F{red}❯%f)'

  # ── context (user@host) ─────────────────────────────────────────────────

  # Fish colors: green user, yellow host
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%F{green}%n%f@%F{yellow}%m%f'
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,REMOTE}_FOREGROUND=default
  typeset -g POWERLEVEL9K_CONTEXT_{SUDO,REMOTE_SUDO,ROOT}_FOREGROUND=red

  # ── dir (current directory) ──────────────────────────────────────────────

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=green
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_from_right
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=false

  # ── vcs (git status — commit hash only) ─────────────────────────────────

  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=default
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=default
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=default
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=red
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=244
  typeset -g POWERLEVEL9K_VCS_PREFIX='on '
  typeset -g POWERLEVEL9K_VCS_SUFFIX=''
  # Format: @commit_hash !num_changes
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='@${${VCS_STATUS_COMMIT[1,8]}:-?}${${VCS_STATUS_NUM_STAGED:#0}:+ !${VCS_STATUS_NUM_STAGED}}${${VCS_STATUS_NUM_UNSTAGED:#0}:+ !${VCS_STATUS_NUM_UNSTAGED}}${${VCS_STATUS_NUM_UNTRACKED:#0}:+ ?${VCS_STATUS_NUM_UNTRACKED}}'
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)

  # ── Misc ─────────────────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
