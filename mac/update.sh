#!/usr/bin/env bash
#
# Apply this repo's macOS system tweaks — the settings a fresh Mac gets wrong.
# Safe to run any time: every setting is compared before it is written, so a
# machine already in the desired state changes nothing and Finder is left alone.
#
#   ./mac/update.sh                      # apply every tweak
#   ./mac/update.sh --check              # report what differs, change nothing
#   ./mac/update.sh --reset-folder-views # also forget per-folder view settings
#
# Finder remembers a view style per folder in that folder's .DS_Store, and a
# saved one wins over the global preference below. So the global default only
# takes effect for folders you have never adjusted by hand. --reset-folder-views
# deletes those files under $HOME, which makes every folder fall back to the
# default — at the cost of any icon positions and window sizes you had set.
# It is deliberately opt-in and never runs from the daily auto-update.

set -euo pipefail

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

[ "$(uname -s)" = Darwin ] || { info "Not macOS — skipping."; exit 0; }

mode=apply
reset_views=no
for arg in "$@"; do
  case "$arg" in
    --check)              mode=check ;;
    --reset-folder-views) reset_views=yes ;;
    -h|--help)            sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                    echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Domains whose settings changed in this run, so only the affected apps are
# restarted — and only when something actually changed. The daily auto-update
# runs this script too, and must not bounce Finder for a no-op. A
# space-delimited string rather than an array: bash 3.2, which is what macOS
# ships, cannot expand an empty array under `set -u`.
changed_domains=" "

mark_changed() {
  case "$changed_domains" in
    *" $1 "*) ;;
    *) changed_domains="$changed_domains$1 " ;;
  esac
}

# set_default <domain> <key> <type> <value> <description>
#
# `defaults read` prints booleans as 0/1 and strings bare, so the comparison is
# against the normalised value rather than what was passed in.
set_default() {
  local domain="$1" key="$2" type="$3" value="$4" desc="$5"
  local want="$value" current

  case "$type" in
    -bool) case "$value" in true|yes|1) want=1 ;; *) want=0 ;; esac ;;
  esac

  current="$(defaults read "$domain" "$key" 2>/dev/null || echo '<unset>')"

  if [ "$current" = "$want" ]; then
    printf '    %-44s ok\n' "$desc"
    return
  fi

  if [ "$mode" = check ]; then
    printf '    %-44s \033[1;33mis %s, want %s\033[0m\n' "$desc" "$current" "$want"
    return
  fi

  defaults write "$domain" "$key" "$type" "$value"
  printf '    %-44s \033[1;32mset\033[0m (was %s)\n' "$desc" "$current"
  mark_changed "$domain"
}

# --- Finder -----------------------------------------------------------------

info "Finder"

# Nlsv = list. The other view styles are icnv (icon), clmv (column),
# Flwv (gallery). This is the view a folder opens in when it has no saved
# setting of its own — see --reset-folder-views above.
set_default com.apple.finder FXPreferredViewStyle -string Nlsv \
  "folders open in list view"

# The same toggle as ⌘⇧. in a Finder window.
set_default com.apple.finder AppleShowAllFiles -bool true \
  "show hidden files"

# Hidden files are only half of it: without this, dotfiles appear but
# Info.plist-style extensions on normal files stay hidden.
set_default NSGlobalDomain AppleShowAllExtensions -bool true \
  "show all file extensions"

# --- Dock -------------------------------------------------------------------

info "Dock"

set_default com.apple.dock autohide -bool true \
  "hides automatically"

# tilesize is the icon edge in points. The System Settings slider spans 16
# (small) to 128 (large); 35 is what this machine is set to.
set_default com.apple.dock tilesize -int 35 \
  "icon size"

# --- per-folder view settings (opt-in) --------------------------------------

if [ "$reset_views" = yes ]; then
  if [ "$mode" = check ]; then
    count="$(find "$HOME" -xdev -name .DS_Store -type f 2>/dev/null | wc -l | tr -d ' ')"
    info "Would delete $count .DS_Store files under $HOME"
  else
    info "Deleting .DS_Store files under $HOME"
    # -xdev keeps this on the boot volume: external disks, network shares and
    # iCloud Drive are somebody else's business.
    count="$(find "$HOME" -xdev -name .DS_Store -type f -print -delete 2>/dev/null | wc -l | tr -d ' ')"
    info "Deleted $count .DS_Store files"
    mark_changed com.apple.finder
  fi
fi

# --- apply ------------------------------------------------------------------

if [ "$mode" = check ]; then
  info "Check only — nothing was changed."
  exit 0
fi

if [ "$changed_domains" = " " ]; then
  info "Already up to date."
  exit 0
fi

# Which app has to be restarted for a changed domain to take effect. Collected
# first and deduplicated, so a run that touched both com.apple.finder and
# NSGlobalDomain does not kill Finder twice.
restart=" "
for domain in $changed_domains; do
  case "$domain" in
    com.apple.finder|NSGlobalDomain) app=Finder ;;
    com.apple.dock)                  app=Dock ;;
    *)                               app="" ;;
  esac
  [ -n "$app" ] || continue
  case "$restart" in
    *" $app "*) ;;
    *) restart="$restart$app " ;;
  esac
done

for app in $restart; do
  info "Restarting $app"
  # These are read at launch, so the settings above only show up after a
  # restart. Finder and Dock are both relaunched automatically by launchd.
  killall "$app" 2>/dev/null || true
done

info "Done."
