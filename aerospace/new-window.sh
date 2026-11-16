#!/usr/bin/env bash
#
# Give every new window a workspace of its own.
#
# Run by AeroSpace's on-window-detected callback (see aerospace.toml), which
# sets AEROSPACE_WINDOW_ID to the window that just appeared. AeroSpace's own
# instinct is to tile it next to whatever is focused; this turns that around:
#
#   - a window that lands somewhere already occupied is sent to the first empty
#     workspace on its monitor, and focus goes with it, so it opens "fullscreen"
#   - a window that lands somewhere empty, or floats (dialogs), is left alone
#   - a native tab of an app in TAB_APPS is stacked onto its sibling instead,
#     so two tabs read as one window rather than a split with a blank half
#
# Splitting is then something you ask for: move a window onto an occupied
# workspace (caps+shift+<ws>) and the two tile left and right.

set -uo pipefail

# exec-and-forget runs with a bare launchd PATH, which does not reach brew.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Apps whose tabs are macOS native tabs. Each tab is a separate window as far
# as the accessibility API is concerned, so AeroSpace tiles a new tab beside
# the old one, and macOS — which insists every tab in a group shares one frame —
# draws the group in one half and leaves the other empty. The cost of listing
# an app here: a genuine second window of it (cmd+N) is stacked like a tab too,
# rather than getting a workspace of its own.
TAB_APPS=(
  com.DanPristupov.Fork
)

id="${AEROSPACE_WINDOW_ID:-}"
[ -n "$id" ] || exit 0

# Several windows can appear at once — an app restoring its session, AeroSpace
# starting up — and without this they would all pick the same empty workspace.
lock="${TMPDIR:-/tmp}/aerospace-new-window.lock"
for _ in $(seq 50); do
  mkdir "$lock" 2>/dev/null && break
  sleep 0.1
done
trap 'rmdir "$lock" 2>/dev/null' EXIT

fields='%{window-id}|%{window-layout}|%{app-bundle-id}|%{workspace}|%{monitor-id}'
line="$(aerospace list-windows --all --format "$fields" | awk -F'|' -v id="$id" '$1 == id')"
[ -n "$line" ] || exit 0 # gone already
IFS='|' read -r _ layout app ws monitor <<<"$line"

[ "$layout" = floating ] && exit 0

others="$(aerospace list-windows --workspace "$ws" --format "$fields" |
  awk -F'|' -v id="$id" '$1 != id && $2 != "floating"')"
[ -n "$others" ] || exit 0 # it has the workspace to itself already

for tab_app in "${TAB_APPS[@]}"; do
  [ "$app" = "$tab_app" ] || continue
  if awk -F'|' -v app="$app" '$3 == app { found = 1 } END { exit !found }' <<<"$others"; then
    # A new tab opens right of the one it was opened from, so its sibling is
    # to the left. Joined and made an accordion, the two share one tile — and,
    # with accordion-padding = 0, one frame, which is what macOS wants.
    aerospace join-with --window-id "$id" left
    aerospace layout --window-id "$id" accordion
    exit 0
  fi
done

target="$(aerospace list-workspaces --monitor "$monitor" --empty --visible no | head -n 1)"
[ -n "$target" ] || exit 0 # every workspace taken: leave it tiled where it is

aerospace move-node-to-workspace --window-id "$id" --focus-follows-window "$target"
