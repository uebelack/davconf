#!/usr/bin/env bash
#
# Build the Synthwave '85 theme and install it into VS Code and Cursor.
#
#   ./vscode/update.sh          # build and install where out of date
#   ./vscode/update.sh --check  # report what would change, change nothing
#
# A symlink into the extensions directory used to be the whole install. It is
# not any more: current VS Code and Cursor keep the list of installed
# extensions in extensions.json beside them and scan that, not the directory.
# A folder nobody registered is not a discovery, it is a leftover — the scan
# writes its name into .obsolete, the delete-later list, and skips it from then
# on. Nothing looks broken from outside: the link is healthy, the manifest is
# valid, the theme simply never appears in the picker. The only line that says
# so is "Marked extension as removed <folder>" in the editor's sharedprocess
# log, once per start.
#
# So the theme is installed the way the editor expects, through its own CLI.
# That means packaging it as a .vsix first: a zip holding the manifest, the
# content-type map and the extension itself. vsce would do it, but it wants
# node and the network for what is three files in an archive, so this builds it
# with zip. The vsix is a build artifact and is not committed. It is rebuilt
# and reinstalled whenever a source file is newer than the installed copy,
# which also means a `git pull` that changes the theme reaches the editor on
# the next run.
#
# The cost of going through the CLI is that the editor now owns a copy, so
# editing vscode/theme no longer shows up on restart alone — it shows up on the
# next run of this script. That is the same trade the intellij module makes.
#
# Selecting the theme is yours to do once per editor: it is a line in that
# editor's settings.json, a file this repo does not own and will not rewrite.
# The module reports which editors have it selected and prints the one step for
# the ones that do not.
#
# Create ~/.config/davconf/no-vscode-theme on a machine that does not want it.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DAVCONF_DIR/vscode/theme"
THEME_NAME="Synthwave '85"
PUBLISHER="davconf"
EXT_NAME="synthwave-85"
EXT_ID="$PUBLISHER.$EXT_NAME"
OPT_OUT="$HOME/.config/davconf/no-vscode-theme"

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

# The installed directory is named <publisher>.<name>-<version>, so the version
# in package.json decides where to look for what is already there.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SRC/package.json" | head -1)"
INSTALL_NAME="$EXT_ID-$VERSION"

# <label>|<extensions dir>|<settings.json>|<app bundle>|<cli>
#
# The extensions directory is not proof of anything on its own: an editor that
# has never installed an extension does not have one yet, and skipping on that
# basis silently ignores a perfectly real editor. So an editor counts as present
# if any of its four traces exist. ~/Applications is checked as well as
# /Applications, since that is where casks land on a machine that does not own
# the latter.
editors=(
  "VS Code|$HOME/.vscode/extensions|$HOME/Library/Application Support/Code/User/settings.json|Visual Studio Code.app|code"
  "VS Code Insiders|$HOME/.vscode-insiders/extensions|$HOME/Library/Application Support/Code - Insiders/User/settings.json|Visual Studio Code - Insiders.app|code-insiders"
  "Cursor|$HOME/.cursor/extensions|$HOME/Library/Application Support/Cursor/User/settings.json|Cursor.app|cursor"
)

info "Editor theme"

# --- build ------------------------------------------------------------------
# A vsix is a zip with three things at the root: the manifest the installer
# reads, the content-type map the zip format wants, and extension/ holding what
# package.json already describes.
build_vsix() {
  local out="$1" stage
  stage="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$stage'" RETURN

  mkdir -p "$stage/extension"
  cp -R "$SRC/package.json" "$SRC/themes" "$stage/extension/"

  cat > "$stage/extension.vsixmanifest" <<EOM
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="$EXT_NAME" Version="$VERSION" Publisher="$PUBLISHER" />
    <DisplayName>$THEME_NAME</DisplayName>
    <Description xml:space="preserve">Outrun / miami-nights theme in the davconf palette.</Description>
    <Tags>theme</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
  </Assets>
</PackageManifest>
EOM

  cat > "$stage/[Content_Types].xml" <<'EOM'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
</Types>
EOM

  # -X drops the extra macOS attributes, so the same sources always produce the
  # same archive.
  (cd "$stage" && zip -q -r -X "$out" 'extension.vsixmanifest' '[Content_Types].xml' extension)
}

vsix=""
ensure_vsix() {
  [ -n "$vsix" ] && return
  vsix="$(mktemp -d)/$EXT_NAME-$VERSION.vsix"
  build_vsix "$vsix"
}

# --- install ----------------------------------------------------------------
found=0
unselected=()
installed=()

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

  # The CLI is what installs, so it has to be found even on a machine where the
  # app was never opened and nothing was added to $PATH. Every bundle ships it
  # in the same place.
  cli_path=""
  if command -v "$cli" >/dev/null 2>&1; then
    cli_path="$(command -v "$cli")"
  else
    for base in "/Applications/$app" "$HOME/Applications/$app"; do
      [ -x "$base/Contents/Resources/app/bin/$cli" ] || continue
      cli_path="$base/Contents/Resources/app/bin/$cli"
      break
    done
  fi

  if [ -z "$cli_path" ]; then
    printf '    %-24s no CLI found, cannot install\n' "$label"
    warn "$label: add its CLI to \$PATH and re-run"
    continue
  fi

  # An earlier version of this module linked the theme in instead of installing
  # it. Clear that link out before installing over it: it occupies the exact
  # directory name the install wants.
  legacy="$ext_dir/$INSTALL_NAME"
  if [ -L "$legacy" ]; then
    if [ "$mode" = check ]; then
      warn "$label: the old symlink at $legacy would be removed"
    else
      rm "$legacy"
    fi
  fi

  # And out of .obsolete, the delete-later list, where that link's name is
  # still sitting — a name listed there is skipped by the next scan whether it
  # is a link or the copy we are about to install. Only our own key goes; the
  # rest of the list is somebody else's business.
  obsolete="$ext_dir/.obsolete"
  if [ -f "$obsolete" ] && grep -q "\"$INSTALL_NAME\"" "$obsolete"; then
    if [ "$mode" = check ]; then
      warn "$label: $INSTALL_NAME is marked obsolete, would be cleared"
    elif command -v python3 >/dev/null; then
      python3 - "$obsolete" "$INSTALL_NAME" <<'PY'
import json, sys

path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    marked = json.load(f)
marked.pop(key, None)
with open(path, "w") as f:
    json.dump(marked, f)
PY
    else
      warn "$label: $INSTALL_NAME is marked obsolete in $obsolete — python3 not found, remove the key by hand"
    fi
  fi

  # Is the installed copy current? Two questions, and the directory on its own
  # answers neither. An uninstall leaves the folder behind to delete later, so
  # a folder can outlive its registration — which is the whole failure this
  # module exists to avoid, and would have it report "up to date" about an
  # extension the editor has already written off. So ask extensions.json, the
  # list the editor actually scans, whether this version is registered, and ask
  # the directory only how old it is.
  registered=no
  manifest="$ext_dir/extensions.json"
  if [ -f "$manifest" ]; then
    if command -v python3 >/dev/null; then
      python3 - "$manifest" "$EXT_ID" "$VERSION" <<'PY' && registered=yes
import json, sys

path, ext_id, version = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path) as f:
        entries = json.load(f)
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if any(
    e.get("identifier", {}).get("id") == ext_id and e.get("version") == version
    for e in entries
) else 1)
PY
    elif grep -q "\"$EXT_ID\"" "$manifest"; then
      registered=yes
    fi
  fi

  # Any source file newer than what is installed means it is not current — the
  # same test the intellij module uses.
  dest="$ext_dir/$INSTALL_NAME/package.json"
  current=no
  if [ "$registered" = yes ] && [ -f "$dest" ]; then
    current=yes
    while IFS= read -r src; do
      [ "$src" -nt "$dest" ] && current=no
    done < <(find "$SRC" -type f)
  fi

  if [ "$current" = yes ]; then
    state="up to date"
  elif [ "$mode" = check ]; then
    state="would be installed"
  else
    ensure_vsix
    # --force reinstalls over the same version, which a rebuilt vsix always is:
    # the version in package.json changes when the theme's shape does, not
    # every time a colour is edited.
    if "$cli_path" --install-extension "$vsix" --force >/dev/null 2>&1; then
      state="installed"
      installed+=("$label")
    else
      printf '    %-24s install failed\n' "$label"
      warn "$label: re-run by hand to see why — $cli_path --install-extension $vsix --force"
      continue
    fi
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

[ "$mode" = check ] && exit 0

if [ ${#installed[@]} -gt 0 ]; then
  warn "Restart to pick up the new copy: ${installed[*]}"
fi

if [ ${#unselected[@]} -gt 0 ]; then
  warn "Select it once in: ${unselected[*]}"
  cat <<EOM
    cmd+shift+p → "Preferences: Color Theme" → $THEME_NAME

    Not wanted on this machine?  touch $OPT_OUT
EOM
fi
