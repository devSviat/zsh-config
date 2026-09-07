# ─────────────────────────────────────────────────────────────────────────────
# Omarchy → zsh bridge
#
# Omarchy ships its interactive shell setup as bash, in
# /usr/share/omarchy/default/bash/, which ~/.zshrc (from devSviat/zsh-config)
# never loads. This file restores it under zsh:
#
#   * envs, aliases and fns/* are sourced VERBATIM from Omarchy, so system
#     updates carry over without touching this file.
#   * init, shell, inputrc and completions are bash-only (mise/zoxide/fzf bash
#     hooks, shopt, readline binds, compgen/COMPREPLY). They are re-done below
#     with zsh equivalents.
#
# Loaded automatically: oh-my-zsh sources $ZSH_CUSTOM/*.zsh.
# Disable with:  OMARCHY_ZSH_BRIDGE=0  (set before ~/.zshrc runs)
# ─────────────────────────────────────────────────────────────────────────────

[[ ${OMARCHY_ZSH_BRIDGE:-1} == 0 ]] && return 0

: ${OMARCHY_PATH:=/usr/share/omarchy}
_omarchy_bash=$OMARCHY_PATH/default/bash

# ── 1. Omarchy's own bash files, run under ksh emulation ─────────────────────
# `emulate ksh -c` makes the emulation *sticky*: functions defined inside it
# keep ksh semantics when they are called later. That is what makes upstream's
# bash idioms behave identically here — 0-indexed arrays (${panes[0]} in tsl),
# negative subscripts (${columns[-1]} in hsl), `printf -v` (hdlm), and globs
# that expand to nothing instead of raising "no matches found" (hdlm, tdlm).
if [[ -d $_omarchy_bash ]]; then
  _omarchy_fns_before=( ${(k)functions} )

  # `unsetopt aliases` is required, not cosmetic: oh-my-zsh's git plugin has
  # already defined `ga`, and zsh expands aliases while *parsing*, so the line
  # `ga() {` in fns/worktrees would be read as `git add() {` — a parse error
  # that drops the rest of the file. Disabling expansion while sourcing lets
  # the definitions through; `alias` statements inside still take effect.
  for _omarchy_f in $_omarchy_bash/envs $_omarchy_bash/aliases $_omarchy_bash/fns/*(N); do
    [[ -r $_omarchy_f ]] && emulate ksh -c "unsetopt aliases; source ${(q)_omarchy_f}"
  done

  # With the functions defined, drop any alias that shadows one of them: at the
  # prompt an alias still wins over a function, so `ga`/`gd` would run the git
  # plugin's `git add`/`git diff` instead of Omarchy's worktree helpers.
  for _omarchy_f in ${${(k)functions}:|_omarchy_fns_before}; do
    (( ${+aliases[$_omarchy_f]} )) && unalias -- $_omarchy_f
  done

  unset _omarchy_f _omarchy_fns_before
fi

# ── 2. fns/ssh-reconnect: one function needs a zsh-safe rewrite ──────────────
# `ssh` and `_ssh_disarm` are used exactly as Omarchy ships them. Only
# `_ssh_interactive` has to be replaced, because it uses two constructs that
# ksh emulation cannot fix:
#   ${letters:i:1} — zsh parses `:i` as a history modifier and errors out;
#                    a variable offset must be written ${letters:$i:1}.
#   local argv=()  — `argv` IS `$@` in zsh, so the function's own `shift` loop
#                    empties it, and `ssh -G` then runs with no arguments.
# Behaviour is otherwise upstream's: true only for a real interactive session
# (a destination, no remote command), failing closed if `ssh -G` cannot resolve.
if (( ${+functions[_ssh_interactive]} )); then
  _ssh_interactive() {
    emulate -L ksh
    local value_opts="BbcDEeFIiJLlmOoPpQRSWw"
    local -a ssh_args=( "$@" )
    local arg letters i dest="" opts_done=""

    while (($#)); do
      arg="$1"
      shift

      if [[ -z $opts_done && $arg == "--" ]]; then
        opts_done=1
      elif [[ -z $opts_done && $arg == -?* ]]; then
        letters="${arg#-}"
        for ((i = 0; i < ${#letters}; i++)); do
          if [[ $value_opts == *"${letters:$i:1}"* ]]; then
            (( i == ${#letters} - 1 )) && shift
            break
          fi
        done
      elif [[ -z $dest ]]; then
        dest="$arg"
      else
        return 1
      fi
    done

    [[ -n $dest ]] || return 1

    local resolved
    resolved=$(command ssh -G "${ssh_args[@]}" 2>/dev/null) || return 1
    ! grep -i '^remotecommand ' <<<"$resolved" | grep -qvi '^remotecommand none$'
  }
fi

# ── 3. init: tool integrations, zsh flavour ──────────────────────────────────
# starship is deliberately NOT started: the prompt is oh-my-posh, set up in
# ~/.config/zsh-config/.zshrc. Running both would fight over PROMPT.
command -v mise   >/dev/null && eval "$(mise activate zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

if command -v try >/dev/null; then
  try() {
    unfunction try
    eval "$(SHELL=${commands[zsh]:-/bin/zsh} command try init ~/Work/tries)"
    try "$@"
  }
fi

if command -v fzf >/dev/null; then
  [[ -r /usr/share/fzf/completion.zsh   ]] && source /usr/share/fzf/completion.zsh
  [[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
fi

# ── 4. shell: history and command hashing ────────────────────────────────────
# HISTFILE/HISTSIZE and the ignoreboth equivalents (hist_ignore_dups +
# hist_ignore_space) already come from oh-my-zsh's lib/history.zsh, so only
# Omarchy's `set +h` needs mirroring — mise rewrites its shims, and a cached
# path would keep pointing at the old one.
unsetopt hash_cmds hash_dirs

# ── 5. inputrc: Omarchy's readline tuning as zle/completion settings ─────────
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # completion-ignore-case on
[[ -n $LS_COLORS ]] && \
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # colored-stats on
LISTMAX=200                                                  # completion-query-items 200
setopt auto_menu                                             # TAB: prefix first, then cycle
bindkey '^[[Z' reverse-menu-complete                         # "\e[Z": menu-complete-backward

# Arrow keys match what you have already typed against your history
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search   # cursor mode
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search   # application mode
bindkey '^[OB' down-line-or-beginning-search

# ── 6. completions: `omarchy` subcommands ────────────────────────────────────
# Upstream's completer is bash (compgen/COMPREPLY). This walks the same
# omarchy-<sub>-<sub> binaries to offer the next segment.
_omarchy() {
  local omarchy_bin bin_dir prefix part next f
  omarchy_bin=${commands[omarchy]}
  [[ -n $omarchy_bin ]] || return 1
  bin_dir=${$(readlink -f -- $omarchy_bin 2>/dev/null || print -r -- $omarchy_bin):h}
  [[ -d $bin_dir ]] || return 1

  prefix=omarchy
  local i
  for (( i = 2; i < CURRENT; i++ )); do
    part=${words[i]}
    [[ -z $part || $part == -* ]] && continue
    prefix+="-$part"
  done

  local -a candidates
  for f in $bin_dir/$prefix-*(N); do
    [[ -f $f && -x $f ]] || continue
    next=${${f:t}#$prefix-}
    next=${next%%-*}
    [[ -n $next ]] && candidates+=( $next )
  done
  (( CURRENT == 2 )) && candidates+=( commands )
  [[ ${words[2]} == commands ]] && (( CURRENT >= 3 )) && \
    candidates+=( --all --json --markdown --check )

  # No subcommand matched, so complete argument *values* instead, from the
  # "# omarchy:args=" line the command file declares (175 of them do). Walk
  # back to the longest omarchy-<...> that is executable, then read the spec:
  # alternatives are separated by " | ", tokens by spaces, and a token like
  # <a|b|c> or [a|b|c] offers its choices for that position.
  if (( ${#candidates} == 0 )); then
    local cmd_path="" cmd_prefix first_arg n j
    for (( n = CURRENT - 2; n >= 0; n-- )); do
      cmd_prefix=omarchy
      for (( j = 1; j <= n; j++ )); do
        part=${words[j+1]}
        [[ -z $part || $part == -* ]] && continue
        cmd_prefix+="-$part"
      done
      if [[ -x $bin_dir/$cmd_prefix ]]; then
        cmd_path=$bin_dir/$cmd_prefix
        first_arg=$(( n + 2 ))          # index in $words of this command's 1st arg
        break
      fi
    done

    if [[ -n $cmd_path ]]; then
      local spec_str alt token actual value ok
      local -a alts spec
      spec_str=$(grep -m 1 '^# omarchy:args=' $cmd_path 2>/dev/null)
      spec_str=${spec_str#*omarchy:args=}
      local cur_idx=$(( CURRENT - first_arg ))   # 0-based arg position being completed
      alts=( ${(ps: | :)spec_str} )

      for alt in $alts; do
        spec=( ${=alt} )
        ok=1
        for (( j = 0; j < cur_idx; j++ )); do
          token=${spec[j+1]}
          actual=${words[first_arg + j]}
          if [[ -z $token ]]; then ok=0; break; fi
          if [[ $token == '<'*'>' || $token == '['*']' ]]; then
            value=${token#<}; value=${value#\[}; value=${value%>}; value=${value%\]}
            if [[ $value == *'|'* ]]; then
              [[ " ${value//|/ } " == *" $actual "* ]] || ok=0
            fi
          elif [[ $token != "$actual" ]]; then
            ok=0
          fi
          (( ok )) || break
        done
        (( ok )) || continue

        token=${spec[cur_idx+1]}
        [[ -n $token ]] || continue
        if [[ $token == '<'*'>' || $token == '['*']' ]]; then
          value=${token#<}; value=${value#\[}; value=${value%>}; value=${value%\]}
          [[ $value == *'|'* ]] && candidates+=( ${(s:|:)value} )
        else
          candidates+=( $token )
        fi
      done
    fi
  fi

  candidates=( ${(u)candidates} )
  if (( ${#candidates} )); then
    _describe -t omarchy-commands 'omarchy command' candidates
  else
    _default
  fi
}
(( ${+functions[compdef]} )) && compdef _omarchy omarchy

# Upstream hides the individual omarchy-* binaries from command completion;
# the unified `omarchy` dispatcher is the entry point.
zstyle ':completion:*:*:-command-:*:commands' ignored-patterns 'omarchy-*'

unset _omarchy_bash
