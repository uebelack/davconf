#!/usr/bin/env bash
#
# Keep the Synthwave '85 Chrome theme built, and say how to load it.
#
#   ./chrome/update.sh          # rebuild the images if they are out of date
#   ./chrome/update.sh --check  # report what would change, change nothing
#
# Chrome only accepts an unpacked extension through its own UI — there is no
# flag, file or preference that installs one from a script — so this module
# builds the theme and then tells you the one manual step. It is a one-off per
# machine; after that this is a no-op that reports the theme as applied.
#
# Because it stays unpacked, Chrome loads it from this checkout every start:
# the directory has to stay where it is, and `git pull` picks up changes to
# the theme the next time Chrome restarts.
#
# Create ~/.config/davconf/no-chrome-theme on a machine that does not want it
# and this module stops asking.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_DIR="$DAVCONF_DIR/chrome/theme"
IMAGES_DIR="$THEME_DIR/images"
GENERATOR="$DAVCONF_DIR/chrome/theme-art.py"
OPT_OUT="$HOME/.config/davconf/no-chrome-theme"
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check) mode=check ;;
    *)       echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ -e "$OPT_OUT" ] && exit 0

info "Chrome theme"

# --- the images -------------------------------------------------------------
# They are committed, so a fresh checkout can load the theme without python.
# Rebuild only when the generator has moved on past them.
stale=no
for name in frame toolbar ntp; do
  img="$IMAGES_DIR/$name.png"
  if [ ! -f "$img" ] || [ "$GENERATOR" -nt "$img" ]; then
    stale=yes
  fi
done

if [ "$stale" = no ]; then
  printf '    %-24s already current\n' "images"
elif [ "$mode" = check ]; then
  warn "the theme images would be re-rendered from $(basename "$GENERATOR")"
elif command -v python3 >/dev/null; then
  python3 "$GENERATOR"
else
  warn "python3 not found — keeping the committed images as they are."
fi

# --- is it actually applied? ------------------------------------------------
# Chrome records the active theme's extension id in each profile's Preferences,
# and the on-disk path of an unpacked extension in its Secure Preferences. If
# the two meet at this directory, the theme is live. Best effort by design: the
# files are Chrome's, not ours, and a miss here is only a stale hint.
applied=""
if [ -d "$CHROME_DIR" ] && command -v python3 >/dev/null; then
  applied="$(python3 - "$CHROME_DIR" "$THEME_DIR" <<'PY' || true
import json, os, sys

chrome, theme = sys.argv[1], os.path.realpath(sys.argv[2])


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


for profile in sorted(os.listdir(chrome)):
    base = os.path.join(chrome, profile)
    prefs = load(os.path.join(base, "Preferences"))
    theme_id = prefs.get("extensions", {}).get("theme", {}).get("id")
    if not theme_id:
        continue
    settings = load(os.path.join(base, "Secure Preferences"))
    entry = settings.get("extensions", {}).get("settings", {}).get(theme_id, {})
    path = entry.get("path")
    if path and os.path.realpath(path) == theme:
        print(profile)
PY
)"
fi

if [ -n "$applied" ]; then
  printf '    %-24s applied in %s\n' "theme" "$(echo "$applied" | paste -sd, -)"
  exit 0
fi

if [ ! -d "$CHROME_DIR" ]; then
  printf '    %-24s Chrome not set up on this machine\n' "theme"
  exit 0
fi

warn "Load the theme once, by hand — Chrome allows no other way:"
cat <<EOM
    1. open chrome://extensions
    2. turn on Developer mode (top right)
    3. Load unpacked, and pick:
       $THEME_DIR

    Chrome keeps reading it from there, so leave the directory in place.
    Not wanted on this machine?  touch $OPT_OUT
EOM
