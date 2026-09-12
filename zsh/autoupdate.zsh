# Daily background refresh of this machine's config.
#
# Sourced from zshrc. When the first interactive shell of the day starts, it
# launches update.sh detached and returns immediately — shell startup is never
# blocked, and closing the terminal does not kill the run.
#
# Knobs, set them in ~/.zshrc.local (before this file is sourced):
#   DAVCONF_AUTO_UPDATE=0          disable entirely
#   DAVCONF_UPDATE_INTERVAL=86400  seconds between runs
#   DAVCONF_UPDATE_PROFILES="dev privat"   brew profiles to include
#
# State lives in ${XDG_STATE_HOME:-~/.local/state}/davconf:
#   last-update  timestamp of the last attempt
#   update.log   output of the most recent run
#   failed       present if that run exited non-zero

_davconf_autoupdate_repo=${${(%):-%x}:A:h:h}

_davconf_autoupdate() {
  emulate -L zsh
  setopt local_options no_notify no_monitor

  local repo=$1
  [[ -x $repo/update.sh ]] || return 0

  # Only for real terminals: not scripts, not `zsh -c`, not an editor's shell.
  [[ -o interactive ]] || return 0
  [[ ${DAVCONF_AUTO_UPDATE:-1} == 1 ]] || return 0

  local state=${XDG_STATE_HOME:-$HOME/.local/state}/davconf
  local stamp=$state/last-update
  local log=$state/update.log
  local lock=$state/update.lock
  local interval=${DAVCONF_UPDATE_INTERVAL:-86400}

  mkdir -p $state 2>/dev/null || return 0

  # Report a failed run once, then clear the marker.
  if [[ -f $state/failed ]]; then
    print -u2 "davconf: last auto-update failed — see $log"
    rm -f $state/failed
  fi

  # Already run within the interval?
  if [[ -f $stamp ]]; then
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 0
    zmodload zsh/datetime 2>/dev/null || return 0
    local -a st
    zstat -A st +mtime $stamp 2>/dev/null || return 0
    (( EPOCHSECONDS - st[1] < interval )) && return 0
  fi

  # mkdir is atomic, so of several terminals opening at once exactly one wins.
  # A lock left behind by a killed run is cleared after an hour.
  if ! mkdir $lock 2>/dev/null; then
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 0
    zmodload zsh/datetime 2>/dev/null || return 0
    local -a lst
    zstat -A lst +mtime $lock 2>/dev/null || return 0
    (( EPOCHSECONDS - lst[1] < 3600 )) && return 0
    rm -rf $lock
    mkdir $lock 2>/dev/null || return 0
  fi

  # Stamp before running, not after: a machine that fails to update should
  # retry tomorrow, not on every single terminal it opens today.
  : >| $stamp

  local -a profiles
  profiles=( ${=DAVCONF_UPDATE_PROFILES:-} )

  print "davconf: updating in the background (log: $log)"

  # &! backgrounds and disowns; ignoring HUP additionally keeps the run alive
  # when the terminal window that started it is closed mid-update.
  {
    trap '' HUP
    {
      print "=== davconf update $(date) ==="
      $repo/update.sh $profiles
    } || : >| $state/failed
    rm -rf $lock
  } >|$log 2>&1 &!
}

_davconf_autoupdate $_davconf_autoupdate_repo
unset _davconf_autoupdate_repo
unfunction _davconf_autoupdate
