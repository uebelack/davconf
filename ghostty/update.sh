#!/usr/bin/env bash
#
# Link this repo's Ghostty configuration into place.
#
#   ./ghostty/update.sh          # link ~/.config/ghostty/config
#   ./ghostty/update.sh --check  # report what would change, change nothing
#
# Safe to run any time: the link is created only when it is missing or points
# somewhere else, and an existing real file is backed up rather than clobbered.
#
# Ghostty reads ~/.config/ghostty/config on macOS as well as Linux (it also
# accepts ~/Library/Application Support/com.mitchellh.ghostty/config, but the
# XDG path works on both and is the one this repo owns). Ghostty follows the
# symlink, so editing ghostty/config here and reloading with cmd+shift+r
# applies the change without a further run of this script.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config/ghostty"
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

src="$DAVCONF_DIR/ghostty/config"
dest="$CONFIG_DIR/config"

info "Linking Ghostty configuration"

if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
  printf '    %-24s already linked\n' "config"
  exit 0
fi

if [ "$mode" = check ]; then
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$dest would be backed up and replaced with a link to $src"
  else
    warn "$dest would be linked to $src"
  fi
  exit 0
fi

mkdir -p "$CONFIG_DIR"

if [ -e "$dest" ] || [ -L "$dest" ]; then
  warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
  mv "$dest" "$dest.$BACKUP_SUFFIX"
fi

ln -s "$src" "$dest"
printf '    %-24s linked\n' "config"

# Ghostty only re-reads its config on request, so a running instance keeps the
# old one until then. Nothing here can reload it for you.
command -v ghostty >/dev/null && \
  info "Reload a running Ghostty with cmd+shift+r to pick this up."
