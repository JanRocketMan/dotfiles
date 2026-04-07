# Powerlevel10k config — fish-like single-line prompt
# Style: user@host ~/short/path ((commit))>

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Left prompt segments
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    context                 # user@host
    dir                     # current directory
    vcs                     # git/jj status
    prompt_char             # > symbol
  )

  # No right prompt
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

  # ── General ──────────────────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_MODE=ascii
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_BACKGROUND=                # no background anywhere
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

  # Disable segment padding (the extra spaces around each segment)
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_END_SEPARATOR=''
  typeset -g POWERLEVEL9K_WHITESPACE_BETWEEN_LEFT_SEGMENTS=' '

  # ── context (user@host) ─────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO,REMOTE,REMOTE_SUDO,ROOT}_FOREGROUND=cyan
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO,REMOTE,REMOTE_SUDO,ROOT}_BACKGROUND=
  typeset -g POWERLEVEL9K_CONTEXT_PREFIX=''
  typeset -g POWERLEVEL9K_CONTEXT_SUFFIX=''

  # ── dir (current directory) ──────────────────────────────────────────────

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=blue
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=blue
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=blue
  # Treat these as anchors (never shorten): home, git root, first component
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=first
  typeset -g POWERLEVEL9K_DIR_PACKAGE_FILE=()
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=false
  typeset -g POWERLEVEL9K_DIR_CLASSES=()
  typeset -g POWERLEVEL9K_DIR_PREFIX=''
  typeset -g POWERLEVEL9K_DIR_SUFFIX=''

  # ── vcs (git/jj status) ─────────────────────────────────────────────────

  typeset -g POWERLEVEL9K_VCS_{CLEAN,MODIFIED,UNTRACKED,CONFLICTED,LOADING}_FOREGROUND=yellow
  typeset -g POWERLEVEL9K_VCS_{CLEAN,MODIFIED,UNTRACKED,CONFLICTED,LOADING}_BACKGROUND=
  typeset -g POWERLEVEL9K_VCS_PREFIX='(('
  typeset -g POWERLEVEL9K_VCS_SUFFIX='))'

  # Use a custom content expansion to show only the short commit hash, nothing else
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${${VCS_STATUS_COMMIT[1,8]}:-?}'
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN=

  # ── prompt_char (> symbol) ───────────────────────────────────────────────

  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=green
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=red
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_{VIINS,VICMD,VIVIS,VIOWR}_CONTENT_EXPANSION='>'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_PREFIX=''
  typeset -g POWERLEVEL9K_PROMPT_CHAR_SUFFIX=' '
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''

  # ── Transient / instant prompt ───────────────────────────────────────────

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
