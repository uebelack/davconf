# Terminal greeting: Synthwave '85 sun, local weather, machine vitals.
#
# Sourced from zshrc for interactive shells. Nothing here may block startup:
# anything slow or networked is read from a cache file and refreshed in the
# background, so the greeting always prints from whatever is already on disk.
#
# Knobs, set them in ~/.zshrc.local:
#   DAVCONF_GREETING=0        no greeting at all
#   DAVCONF_GREETING_ART=0    vitals only, skip the sun
#   DAVCONF_WEATHER_LOCATION  default Basel
#
# The art is generated, not hand-typed — see zsh/greeting-art.py.

[[ -o interactive ]] || return 0
[[ ${DAVCONF_GREETING:-1} == 1 ]] || return 0

_davconf_greet() {
  emulate -L zsh
  setopt local_options no_notify no_monitor

  local state=${XDG_STATE_HOME:-$HOME/.local/state}/davconf
  mkdir -p $state 2>/dev/null || return 0

  zmodload zsh/datetime 2>/dev/null
  zmodload -F zsh/stat b:zstat 2>/dev/null

  # --- cache ---------------------------------------------------------------
  # Print whatever is cached, then refresh in the background when stale. The
  # first shell on a new machine shows a placeholder; the next one is correct.
  local -a _refresh
  # Sets REPLY to the cached value and returns 0, or returns 1 when nothing is
  # cached yet — callers must not read meaning into an empty REPLY. Queues a
  # background refresh when the entry is stale or absent.
  #
  # NOTE: call this directly, never as "$(_cache …)". Command substitution runs
  # in a subshell, where the appends to _refresh are thrown away and the cache
  # would never be written at all.
  _cache() {   # _cache <name> <ttl-seconds> <command…>
    local name=$1 ttl=$2; shift 2
    local file=$state/cache-$name
    local -a st
    local fresh=0 have=1
    REPLY=
    if [[ -f $file ]] && zstat -A st +mtime $file 2>/dev/null; then
      (( EPOCHSECONDS - st[1] < ttl )) && fresh=1
      REPLY="$(<$file)"
    else
      have=0
    fi
    (( fresh )) || _refresh+=( "${(j: :)${(q)@}} >| ${(q)file}.tmp 2>/dev/null && mv ${(q)file}.tmp ${(q)file} || rm -f ${(q)file}.tmp" )
    return $(( 1 - have ))
  }

  # --- vitals --------------------------------------------------------------
  local loc=${DAVCONF_WEATHER_LOCATION:-Basel}
  local weather brewout brewknown=0

  # The weather is the only thing in this greeting that leaves the machine, so
  # it is the only thing a corporate proxy breaks. curl does read the
  # environment itself, but not every spelling of it: https_proxy, HTTPS_PROXY
  # and lowercase http_proxy are honoured, while an uppercase HTTP_PROXY is
  # deliberately ignored — a CGI script would otherwise inherit one straight
  # from a request header. A machine that exports only the uppercase pair
  # therefore fetches direct, and on a network that requires the proxy that is
  # eight seconds of nothing, every terminal, until the timeout gives up.
  #
  # So: resolve it here, accept every spelling, and ask over https — which also
  # means HTTPS_PROXY is the variable that applies. no_proxy is passed along as
  # --noproxy so an exclusion list still excludes.
  local -a curl_opts=(-fsS --max-time 8)
  # In order of how specific the variable is to this request. The http_* pair
  # comes last and is strictly a fallback: it names a proxy for http, not for
  # the https we are asking over — but a machine that sets only that pair means
  # the same host, and going direct there means going nowhere.
  local proxy=${https_proxy:-${HTTPS_PROXY:-${all_proxy:-${ALL_PROXY:-${http_proxy:-${HTTP_PROXY:-}}}}}}
  local noproxy=${no_proxy:-${NO_PROXY:-}}
  [[ -n $proxy   ]] && curl_opts+=(--proxy $proxy)
  [[ -n $noproxy ]] && curl_opts+=(--noproxy $noproxy)

  _cache weather 1800 curl $curl_opts "https://wttr.in/${loc}?format=%c%t+%w&m"
  weather=$REPLY
  _cache brew-outdated 900 brew outdated --quiet && brewknown=1
  brewout=$REPLY

  # Uptime from the boot clock — parsing `uptime` is a format-guessing game.
  local up="?"
  local boot=0
  if [[ -r /proc/uptime ]]; then
    boot=$(( EPOCHSECONDS - ${$(</proc/uptime)%%.*} ))
  else
    # Anchored: a greedy .* would match "usec =" and read the microseconds.
    boot=$(sysctl -n kern.boottime 2>/dev/null | sed -nE 's/^\{ sec = ([0-9]+).*/\1/p')
  fi
  if [[ -n $boot ]] && (( boot > 0 )); then
    local secs=$(( EPOCHSECONDS - boot ))
    if   (( secs < 3600  )); then up="$(( secs / 60 ))m"
    elif (( secs < 86400 )); then up="$(( secs / 3600 ))h $(( secs % 3600 / 60 ))m"
    else                          up="$(( secs / 86400 ))d $(( secs % 86400 / 3600 ))h"
    fi
  fi
  local disk="$(df -h / 2>/dev/null | awk 'NR==2 {print $4" free"}')"
  local batt="$(pmset -g batt 2>/dev/null | awk -F'\t' 'NR==2 {split($2,a,";"); print a[1]}')"

  # Last successful davconf sync, from the auto-update stamp.
  local synced="never"
  local -a st
  if [[ -f $state/last-update ]] && zstat -A st +mtime $state/last-update 2>/dev/null; then
    local age=$(( EPOCHSECONDS - st[1] ))
    if   (( age < 3600  )); then synced="$(( age / 60 ))m ago"
    elif (( age < 86400 )); then synced="$(( age / 3600 ))h ago"
    else                         synced="$(( age / 86400 ))d ago"
    fi
  fi

  # Never claim "up to date" from a cache that has not been written yet.
  local brewtxt="…"
  if (( brewknown )); then
    if [[ -n $brewout ]]; then brewtxt="${#${(f)brewout}} outdated"
    else                       brewtxt="up to date"
    fi
  fi

  # --- palette (Synthwave '85) ---------------------------------------------
  local P=$'\e[38;2;249;42;173m'    # magenta
  local C=$'\e[38;2;0;240;255m'     # cyan
  local Y=$'\e[38;2;254;222;93m'    # yellow
  local D=$'\e[38;2;73;84;149m'     # dim blue
  local W=$'\e[38;2;212;200;255m'   # soft white
  local X=$'\e[0m'

  local -a quotes=(
    'Wake up, Neo…'
    'The future is already here — it is just not evenly distributed.'
    'It is not a bug, it is an undocumented feature.'
    'I know this. This is a UNIX system.'
    'Never send a human to do a machine job.'
    'There is no patch for human stupidity.'
    'Hack the planet.'
    'Talk is cheap. Show me the code.'
    'Programs must be written for people to read.'
    'Access denied. Trying again anyway.'
  )
  local quote=${quotes[RANDOM % $#quotes + 1]}

  # --- panel ---------------------------------------------------------------
  local -a info
  info=(
    "${P}DAVCONF${X} ${D}·${X} ${C}SYNTHWAVE '85${X}"
    "${D}──────────────────────────────${X}"
    "${C}WEATHER${X}  ${W}${loc}  ${weather:-…}${X}"
    "${C}UPTIME${X}   ${W}${up:-?}${X}"
    "${C}DISK${X}     ${W}${disk:-?}${X}"
    "${C}POWER${X}    ${W}${batt:-?}${X}"
    "${C}BREW${X}     ${W}${brewtxt}${X}"
    "${C}UPDATE${X}   ${W}${synced}${X}"
    ""
    "${D}${quote}${X}"
  )

  local -a art
  art=(
  '      \e[38;2;254;212;93;49m▄▄▄▄\e[0m\e[38;2;254;222;93;48;2;254;212;93m▀▀▀▀▀▀▀▀▀▀\e[0m\e[38;2;254;212;93;49m▄▄▄▄\e[0m      '
  '   \e[38;2;255;184;83;49m▄\e[0m\e[38;2;255;201;93;48;2;255;184;83m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m\e[38;2;255;184;83;49m▄\e[0m   '
  ' \e[38;2;255;152;65;49m▄\e[0m\e[38;2;255;164;72;48;2;255;152;65m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m\e[38;2;255;152;65;49m▄\e[0m '
  '\e[38;2;255;143;59;48;2;255;120;63m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m'
  '\e[38;2;254;87;74;49m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m'
  ' \e[38;2;251;51;142;49m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m '
  '   \e[38;2;250;78;187;49m▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀\e[0m   '
  '          \e[38;2;255;126;219;49m▄▄▄▄▄▄▄▄▄▄\e[0m          '
  '\e[38;2;3;237;249m╲   ╲   ╲  ╲ ╲│╱ ╱  ╱   ╱   ╱\e[0m '
  '\e[38;2;3;237;249m──────────────┼──────────────\e[0m '
  )

  print
  if [[ ${DAVCONF_GREETING_ART:-1} == 1 ]]; then
    local i
    for (( i = 1; i <= $#art; i++ )); do
      printf '%b  %s\n' "${art[i]}" "${info[i]}"
    done
  else
    print -l -- ${info}
  fi
  print

  # --- background refresh --------------------------------------------------
  # Detached and HUP-proof, exactly like the auto-update: closing the window
  # must not leave a half-written cache file behind.
  if (( $#_refresh )); then
    local cmd
    { trap '' HUP
      for cmd in $_refresh; do eval $cmd; done
    } >/dev/null 2>&1 &!
  fi
}

_davconf_greet
unfunction _davconf_greet _cache 2>/dev/null
