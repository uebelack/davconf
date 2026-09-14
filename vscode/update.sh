#!/usr/bin/env bash
#
# Link the Synthwave '85 theme into VS Code and Cursor.
#
#   ./vscode/update.sh          # link into every editor found
#   ./vscode/update.sh --check  # report what would change, change nothing
#
# Both editors scan their extensions directory at startup and follow symlinks,
# so a link is all it takes — no packaging, no marketplace, and editing the
# theme in this repo reaches the editor on its next restart. Cursor is a VS Code
# fork and reads the same extension format, which is why one directory serves
# both.
#
# Selecting the theme is yours to do once per editor: it is a line in that
# editor's settings.json, a file this repo does not own and will not rewrite.
# The module reports which editors have it selected and prints the one step for
# the ones that do not.
#
# Create ~/.config/davconf/no-vscode-theme on a machine that does not want it.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_SRC="$DAVCONF_DIR/vscode/theme"
THEME_NAME="Synthwave '85"
LINK_NAME="davconf.synthwave-85-1.0.0"
OPT_OUT="$HOME/.config/davconf/no-vscode-theme"
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

[ -e "$OPT_OUT" ] && exit 0

# <label>|<extensions dir>|<settings.json>|<app bundle>|<cli>
#
# The extensions directory is not proof of anything on its own: an editor that
# has never installed an extension does not have one yet, and skipping on that
# basis silently ignores a perfectly real editor. So an editor counts as present
# if any of its four traces exist, and the directory is created when it is the
# missing one. ~/Applications is checked as well as /Applications, since that is
# where casks land on a machine that does not own the latter.
editors=(
  "VS Code|$HOME/.vscode/extensions|$HOME/Library/Application Support/Code/User/settings.json|Visual Studio Code.app|code"
  "VS Code Insiders|$HOME/.vscode-insiders/extensions|$HOME/Library/Application Support/Code - Insiders/User/settings.json|Visual Studio Code - Insiders.app|code-insiders"
  "Cursor|$HOME/.cursor/extensions|$HOME/Library/Application Support/Cursor/User/settings.json|Cursor.app|cursor"
)

info "Editor theme"

found=0
unselected=()

for entry in "${editors[@]}"; do
  IFS='|' read -r label ext_dir settings app cli <<<"$entry"

  present=no
  [ -d "$ext_dir" ] && present=yes
  [ -f "$settings" ] && present=yes
  [ -d "/Applications/$app" ] && present=yes
  [ -d "$HOME/Applications/$app" ] && present=yes
  command -v "$cli" >/dev/null 2>&1 && present=yes
  [ "$present" = yes ] || continue

  found=1

  if [ ! -d "$ext_dir" ]; then
    if [ "$mode" = check ]; then
      warn "$label: $ext_dir would be created"
    else
      mkdir -p "$ext_dir"
    fi
  fi

  dest="$ext_dir/$LINK_NAME"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$THEME_SRC" ]; then
    state="linked"
  elif [ "$mode" = check ]; then
    state="would be linked"
  else
    # A real directory here is somebody else's copy of the theme, not ours.
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
      mv "$dest" "$dest.$BACKUP_SUFFIX"
    fi
    ln -s "$THEME_SRC" "$dest"
    state="linked"
  fi

  # Is it the selected theme? settings.json is JSON with comments and trailing
  # commas, which no standard parser accepts — so read just the one line rather
  # than pretending to parse the file.
  selected=no
  if [ -f "$settings" ] &&
     grep -q "\"workbench.colorTheme\"[[:space:]]*:[[:space:]]*\"$THEME_NAME\"" "$settings"; then
    selected=yes
  fi

  if [ "$selected" = yes ]; then
    printf '    %-24s %s, selected\n' "$label" "$state"
  else
    printf '    %-24s %s\n' "$label" "$state"
    unselected+=("$label")
  fi
done

if [ "$found" = 0 ]; then
  printf '    %-24s no editor installed\n' "theme"
  exit 0
fi

if [ ${#unselected[@]} -gt 0 ] && [ "$mode" != check ]; then
  warn "Select it once in: ${unselected[*]}"
  cat <<EOM
    cmd+shift+p → "Preferences: Color Theme" → $THEME_NAME
    (restart the editor first if it was running when this linked the theme)

    Not wanted on this machine?  touch $OPT_OUT
EOM
fi
