#!/usr/bin/env bash
#
# Install the focus-theft watcher: a LaunchAgent that logs which application
# takes window focus, and whether you asked it to.
#
#   ./focus/update.sh           # install or refresh the agent, link the commands
#   ./focus/update.sh --check   # report what would change, change nothing
#   ./focus/update.sh --off     # unload the agent and remove the plist
#
# For the complaint "something keeps stealing focus and my keystrokes go
# nowhere". focus-watch samples the front application and reads the HID idle
# timer; focus-report tells you who did it. See focus/focus-watch for how, and
# why it is not the Swift daemon this is modelled on.
#
# --- opt-in, unlike every other module in this repo --------------------------
# The rest of davconf is opt-*out*: it applies everywhere and a marker file
# turns it off, because the rest of davconf is configuration — a symlink, a
# default, a package — that costs nothing to have.
#
# This one is a process that runs forever. One of these machines has the focus
# problem; the others would be running a daemon for a symptom they do not have,
# and "harmless background thing nobody remembers enabling" is how machines get
# slow. So it installs nothing until the machine says it wants it:
#
#   touch ~/.config/davconf/focus-watch
#
# and stops when that file goes away. Which machine wants it is per-machine
# state, exactly like ~/.config/davconf/profiles, so it is not committed.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL=dev.uebelacker.davconf.focus
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
MARKER="${XDG_CONFIG_HOME:-$HOME/.config}/davconf/focus-watch"
LOG_DIR="$HOME/Library/Logs/davconf"
BIN_DIR="$HOME/bin"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check)   mode=check ;;
    --off)     mode=off ;;
    -h|--help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ "$(uname -s)" = Darwin ] || { info "Not macOS — skipping."; exit 0; }

# gui/<uid> is the domain a per-user agent lives in. bootout of something that
# is not loaded is an error, which is not interesting here either way.
unload() { launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true; }

# --- off --------------------------------------------------------------------
if [ "$mode" = off ]; then
  unload
  rm -f "$PLIST"
  info "Watcher stopped and $PLIST removed."
  info "The log is left where it is: $LOG_DIR/focus.tsv"
  info "To stop it coming back on the next run: rm $MARKER"
  exit 0
fi

# --- opt-in -----------------------------------------------------------------
if [ ! -e "$MARKER" ]; then
  # Already running from a previous opt-in? Then the marker going away is an
  # instruction, not an absence — tidy up rather than leaving an orphan daemon.
  if [ -e "$PLIST" ]; then
    if [ "$mode" = check ]; then
      warn "$MARKER is gone — the agent would be unloaded and $PLIST removed."
      exit 0
    fi
    warn "$MARKER is gone — stopping the watcher."
    unload
    rm -f "$PLIST"
    # ~/bin/focus-report is left in place on purpose: the log it reads is still
    # there, and whatever you collected is the reason you turned this on.
    warn "focus-report stays on \$PATH — the log it reads is still at $LOG_DIR/focus.tsv"
    exit 0
  fi
  info "Not enabled on this machine. To turn it on:"
  info "  mkdir -p ${MARKER%/*} && touch $MARKER && ./focus/update.sh"
  exit 0
fi

watch="$DAVCONF_DIR/focus/focus-watch"
[ -x "$watch" ] || { echo "$watch is missing or not executable" >&2; exit 1; }

# The plist is generated rather than committed, because it has to name an
# absolute path to this checkout and $HOME, and neither is the same on two
# machines. Written to a temp file and compared, so an unchanged agent is not
# torn down and restarted on every daily run.
desired="$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>              <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$watch</string>
  </array>
  <key>RunAtLoad</key>          <true/>
  <key>KeepAlive</key>          <true/>
  <!-- Background: the scheduler may deprioritise it freely. It samples twice a
       second and nothing waits on the result. -->
  <key>ProcessType</key>        <string>Background</string>
  <key>StandardErrorPath</key>  <string>$LOG_DIR/focus-watch.err</string>
</dict>
</plist>
PLISTEOF
)"

if [ -f "$PLIST" ] && [ "$(cat "$PLIST")" = "$desired" ]; then
  plist_state=current
elif [ -f "$PLIST" ]; then
  plist_state=stale
else
  plist_state=absent
fi

# Is it actually running? A plist on disk is not an agent in the domain — after
# a crash loop or a manual bootout the two disagree, and the daily run should
# notice rather than report success because a file exists.
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  running=yes
else
  running=no
fi

if [ "$mode" = check ]; then
  info "Focus watcher"
  printf '    %-24s %s\n' "plist" "$plist_state"
  printf '    %-24s %s\n' "loaded" "$running"
  if [ "$plist_state" = current ] && [ "$running" = yes ]; then
    info "Nothing to do."
  else
    warn "A run would install and load it."
  fi
  exit 0
fi

info "Focus watcher"
mkdir -p "$LOG_DIR" "$BIN_DIR" "$(dirname "$PLIST")"

# focus-report is only useful if it is on $PATH; zsh/zshrc already puts ~/bin
# first, so that is where it goes. Symlinks, so editing the script in the repo
# takes effect without another run.
for cmd in focus-watch focus-report; do
  if [ -L "$BIN_DIR/$cmd" ] && [ "$(readlink "$BIN_DIR/$cmd")" = "$DAVCONF_DIR/focus/$cmd" ]; then
    printf '    %-24s already linked\n' "~/bin/$cmd"
  else
    # rm -f covers all three cases — a link to somewhere else, a real file, or
    # nothing at all — and none of them holds anything worth keeping: the only
    # content is in the repo.
    rm -f "$BIN_DIR/$cmd"
    ln -s "$DAVCONF_DIR/focus/$cmd" "$BIN_DIR/$cmd"
    printf '    %-24s linked\n' "~/bin/$cmd"
  fi
done

if [ "$plist_state" = current ] && [ "$running" = yes ]; then
  printf '    %-24s running\n' "launchagent"
else
  if [ "$plist_state" != current ]; then
    printf '%s\n' "$desired" > "$PLIST"
    printf '    %-24s %s\n' "launchagent" "plist written"
  fi
  # bootout then bootstrap: launchctl has no reload, and bootstrapping a label
  # already in the domain fails rather than replacing it.
  unload
  if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
    printf '    %-24s loaded\n' "launchagent"
  else
    warn "launchctl bootstrap failed — the plist is in place, so try:"
    warn "  launchctl bootstrap gui/$(id -u) $PLIST"
    exit 1
  fi
fi

info "Logging to $LOG_DIR/focus.tsv — read it with: focus-report"
