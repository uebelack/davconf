#!/usr/bin/env bash
#
# Check the themes in this repo against the palette they are all copies of.
#
#   ./palette/update.sh          # report any theme that has drifted
#   ./palette/update.sh --check  # the same thing — this module only ever checks
#
# Unlike every other module here, this one configures nothing on the machine.
# There is no file to link: palette/synthwave-85.json is read by people and by
# palette.py, never by a program on this Mac. What it does instead is notice
# when ghostty/config, the Neovim colour scheme or a wallpaper prompt stops
# agreeing with it — which is the failure that made a single palette file worth
# having, and the one that is otherwise invisible until two windows are open
# side by side and one of them is slightly the wrong pink.
#
# It runs on both kinds of machine, because the two themes it checks are the
# two the headless box also has.
#
# A failure here is a disagreement, not a broken machine: either the theme is
# wrong and should be corrected, or the palette moved on purpose and the JSON
# is what needs the edit. update.sh carries on with the rest of the modules
# either way, and names this one at the end.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

for arg in "$@"; do
  case "$arg" in
    --check) ;;
    *)       echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

info "Checking the themes against palette/synthwave-85.json"

if python3 "$DAVCONF_DIR/palette/palette.py" --check; then
  printf '    %-24s in palette\n' "every theme"
  exit 0
fi

warn "The themes above disagree with palette/synthwave-85.json."
warn "Fix the theme, or edit the palette if the colour moved on purpose."
exit 1
