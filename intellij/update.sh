#!/usr/bin/env bash
#
# Build the Synthwave '85 theme plugin and install it into every JetBrains IDE
# on this machine.
#
#   ./intellij/update.sh          # build and install where out of date
#   ./intellij/update.sh --check  # report what would change, change nothing
#
# JetBrains IDEs will not read a loose theme file the way VS Code does: a UI
# theme has to be a plugin. This one has no code — just plugin.xml, the theme
# JSON and the editor colour scheme — so "building" it is zipping three files
# into a jar, no Gradle and no JDK required.
#
# The jar is a build artifact, so it is not committed: it is rebuilt from
# intellij/theme whenever a source file is newer than the installed copy, which
# also means a `git pull` that changes the theme reinstalls it on the next run.
#
# Selecting the theme is yours to do once per IDE, in Settings → Appearance.
# This module will not write it: the IDE rewrites options/*.xml when it exits
# and would drop anything we put there while it was running.
#
# Create ~/.config/davconf/no-intellij-theme on a machine that does not want it.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DAVCONF_DIR/intellij/theme"
PLUGIN_DIR="davconf-synthwave-85"
JAR="synthwave-85.jar"
THEME_ID="f6c1653d-bea4-475c-9ccb-0433bee865d5"
THEME_NAME="Synthwave '85"
OPT_OUT="$HOME/.config/davconf/no-intellij-theme"

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

info "IDE theme"

# --- which IDEs are on this machine -----------------------------------------
# Every JetBrains config directory has an options/ — Toolbox's own directory
# sits beside them and does not, which is the difference this looks for.
ides=()
for dir in "$HOME/Library/Application Support/JetBrains"/*/ \
           "$HOME/Library/Application Support/Google"/AndroidStudio*/; do
  [ -d "$dir/options" ] || continue
  ides+=("${dir%/}")
done

if [ ${#ides[@]} -eq 0 ]; then
  printf '    %-24s no JetBrains IDE installed\n' "theme"
  exit 0
fi

# --- build ------------------------------------------------------------------
build_jar() {
  local out="$1" stage
  stage="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$stage'" RETURN

  cp -R "$SRC/META-INF" "$SRC/themes" "$stage/"
  printf 'Manifest-Version: 1.0\nCreated-By: davconf\n' > "$stage/META-INF/MANIFEST.MF"

  # A jar is a zip. -X drops the extra macOS attributes, so the same sources
  # always produce the same archive.
  (cd "$stage" && zip -q -r -X "$out" META-INF themes)
}

jar_built=""
needs_build=no
for ide in "${ides[@]}"; do
  dest="$ide/plugins/$PLUGIN_DIR/lib/$JAR"
  if [ ! -f "$dest" ]; then
    needs_build=yes
    continue
  fi
  while IFS= read -r src; do
    [ "$src" -nt "$dest" ] && needs_build=yes
  done < <(find "$SRC" -type f)
done

if [ "$needs_build" = yes ] && [ "$mode" = apply ]; then
  jar_built="$(mktemp -d)/$JAR"
  build_jar "$jar_built"
fi

# --- install ----------------------------------------------------------------
stale=()
for ide in "${ides[@]}"; do
  label="$(basename "$ide")"
  dest_dir="$ide/plugins/$PLUGIN_DIR/lib"
  dest="$dest_dir/$JAR"

  current=no
  if [ -f "$dest" ]; then
    current=yes
    while IFS= read -r src; do
      [ "$src" -nt "$dest" ] && current=no
    done < <(find "$SRC" -type f)
  fi

  if [ "$current" = no ]; then
    if [ "$mode" = check ]; then
      warn "$label: the theme plugin would be built and installed"
      continue
    fi
    mkdir -p "$dest_dir"
    cp "$jar_built" "$dest"
    state="installed"
  else
    state="up to date"
  fi

  # Best effort: the IDE records the active theme by its themeProvider id in
  # options/laf.xml. Absent or unreadable just means the hint below is printed.
  if grep -q "$THEME_ID\|$THEME_NAME" "$ide/options/laf.xml" 2>/dev/null; then
    printf '    %-24s %s, selected\n' "$label" "$state"
  else
    printf '    %-24s %s\n' "$label" "$state"
    stale+=("$label")
  fi
done

[ "$mode" = check ] && exit 0

if [ ${#stale[@]} -gt 0 ]; then
  warn "Select it once in: ${stale[*]}"
  cat <<EOM
    restart the IDE, then
    Settings → Appearance & Behavior → Appearance → Theme → $THEME_NAME
    (the editor colours come with it — no second setting to change)

    Not wanted on this machine?  touch $OPT_OUT
EOM
fi
