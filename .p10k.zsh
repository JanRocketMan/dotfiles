# Powerlevel10k config — fish-like single-line prompt
# Style: user@host ~/shortened/path ((commit))>

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Left prompt segments
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    context                 # user@host
    dir                     # current directory
    vcs                     # git/jj status
    prompt_char             # prompt symbol (> or red > on error)
  )

  # No right prompt
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

  # ── General ──────────────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_MODE=ascii
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

  # No background colors — clean text-only look
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

  # ── context (user@host) ─────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
  typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=cyan
  typeset -g POWERLEVEL9K_CONTEXT_BACKGROUND=
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=red
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND=
  # Always show context (not just in SSH)
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO,REMOTE,REMOTE_SUDO}_FOREGROUND=cyan
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO,REMOTE,REMOTE_SUDO}_BACKGROUND=

  # ── dir (current directory) ──────────────────────────────────────────────

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=blue
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
  # Show ~ for home
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=false
  # No icons/lock symbols
  typeset -g POWERLEVEL9K_DIR_PREFIX=''
  typeset -g POWERLEVEL9K_DIR_SUFFIX=' '

  # ── vcs (git/jj status) ─────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_VCS_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_BACKGROUND=
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=

  # Wrap in (( )) like fish
  typeset -g POWERLEVEL9K_VCS_PREFIX='(('
  typeset -g POWERLEVEL9K_VCS_SUFFIX='))'

  # Show short commit hash, hide icons
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=
  typeset -g POWERLEVEL9K_VCS_COMMIT_ICON=
  typeset -g POWERLEVEL9K_VCS_STAGED_ICON='+'
  typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON='*'
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'
  typeset -g POWERLEVEL9K_VCS_STASH_ICON='#'
  typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON=
  typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON=

  # ── prompt_char (> symbol) ───────────────────────────────────────────────

  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=green
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=red
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='>'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='>'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='>'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='>'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=' '

  # ── Transient prompt ─────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off

  # ── Instant prompt ───────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # ── Disable unused segments ──────────────────────────────────────────────

  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=false
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=green
  typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND=

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
