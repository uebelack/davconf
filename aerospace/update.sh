#!/usr/bin/env bash
#
# Link this repo's AeroSpace configuration into place.
#
#   ./aerospace/update.sh          # link ~/.aerospace.toml
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

src="$DAVCONF_DIR/aerospace/aerospace.toml"
dest="$HOME/.aerospace.toml"

info "Linking AeroSpace configuration"

# The XDG path is the fallback AeroSpace never reaches while the link above
# exists. Say so rather than delete somebody's file.
xdg="$HOME/.config/aerospace/aerospace.toml"
[ -e "$xdg" ] && warn "$xdg is shadowed by $dest and is not being read"

linked=no
if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
  printf '    %-24s already linked\n' "aerospace.toml"
  linked=yes
elif [ "$mode" = check ]; then
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$dest would be backed up and replaced with a link to $src"
  else
    warn "$dest would be linked to $src"
  fi
  exit 0
else
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  fi
  ln -s "$src" "$dest"
  printf '    %-24s linked\n' "aerospace.toml"
fi

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
elif [ "$linked" = no ]; then
  info "AeroSpace is not running — the config applies the next time it starts."
fi
