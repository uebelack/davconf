#!/usr/bin/env bash
#
# Link this repo's AeroSpace configuration into place.
#
#   ./aerospace/update.sh          # link ~/.aerospace.toml and new-window.sh
#   ./aerospace/update.sh --check  # report what would change, change nothing
#
# Safe to run any time: the link is created only when it is missing or points
# somewhere else, and an existing real file is backed up rather than clobbered.
#
# AeroSpace reads ~/.aerospace.toml first and only falls back to
# ~/.config/aerospace/aerospace.toml, so this repo owns the first path — the
# one that wins — and the second should stay absent.
#
# Unlike the terminal, a running AeroSpace can be told to re-read its config,
# so this script does that itself and the change applies without a restart.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check) mode=check ;;
    *)       echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

info "Linking AeroSpace configuration"

# The XDG path is the fallback AeroSpace never reaches while ~/.aerospace.toml
# exists. Say so rather than delete somebody's file.
xdg="$HOME/.config/aerospace/aerospace.toml"
[ -e "$xdg" ] && warn "$xdg is shadowed by $HOME/.aerospace.toml and is not being read"

# link <file in aerospace/> <destination>
changed=no
link() {
  local src="$DAVCONF_DIR/aerospace/$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    printf '    %-24s already linked\n' "$1"
    return
  fi
  changed=yes
  if [ "$mode" = check ]; then
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      warn "$dest would be backed up and replaced with a link to $src"
    else
      warn "$dest would be linked to $src"
    fi
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  printf '    %-24s linked\n' "$1"
}

link aerospace.toml "$HOME/.aerospace.toml"
# Run by the on-window-detected callback. It sits beside the shadowed XDG
# config, not in it — only aerospace.toml there would be a second config.
link new-window.sh "$HOME/.config/aerospace/new-window.sh"

[ "$mode" = check ] && exit 0

# Only worth doing when it is actually running — `aerospace` exits non-zero
# with "connection refused" otherwise, which is not a failure of this script.
if pgrep -x AeroSpace >/dev/null 2>&1 && command -v aerospace >/dev/null; then
  if out="$(aerospace reload-config 2>&1)"; then
    printf '    %-24s reloaded\n' "running instance"
  else
    warn "aerospace reload-config failed:"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
elif [ "$changed" = yes ]; then
  info "AeroSpace is not running — the config applies the next time it starts."
fi
