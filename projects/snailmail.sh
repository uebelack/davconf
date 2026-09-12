#!/usr/bin/env bash
#
# Check out the snailmail project: create ~/projects/snailmail and clone every
# repository it is made of.
#
#   ./projects/snailmail.sh            # clone what is missing, pull the rest
#   ./projects/snailmail.sh --check    # report what would happen, change nothing
#   ./projects/snailmail.sh --no-pull  # clone what is missing, touch nothing else
#
# Run it by hand — this is not part of update.sh, because which projects a
# machine wants checked out is a per-machine decision, not shared config.
#
# Safe to run any time: an existing checkout is fast-forwarded, never reset, so
# local work is not at risk. A repo that cannot be fast-forwarded is reported
# and skipped. One failing repo does not stop the others; the exit status is
# non-zero if any of them failed, and the summary at the end says which.

set -uo pipefail

# --- the repositories -------------------------------------------------------
# "<directory> <clone URL>", one per line. The directory is not always the repo
# name — snailmail-ios comes from the repo simply called "snailmail" — so both
# are spelled out rather than derived.
REPOS="
briefe.app                             git@github.com:uebelack/briefe.app.git
snailmail-backend                      git@github.com:uebelack/snailmail-backend.git
snailmail-ios                          git@github.com:uebelack/snailmail.git
snailmail-android                      git@github.com:uebelack/snailmail-android.git
snailmail-ios-screenshot-generator     git@github.com:uebelack/snailmail-ios-screenshot-generator.git
snailmail-android-screenshot-generator git@github.com:uebelack/snailmail-android-screenshot-generator.git
"

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
TARGET="$PROJECTS_DIR/snailmail"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
pull=yes
for arg in "$@"; do
  case "$arg" in
    --check)   mode=check ;;
    --no-pull) pull=no ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *)         echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null || { echo "git is not installed" >&2; exit 1; }

if [ "$mode" = check ]; then
  info "Would check out into $TARGET"
else
  info "Checking out into $TARGET"
  mkdir -p "$TARGET"
fi

cloned=0 updated=0 skipped=0
failed=()

while read -r dir url; do
  [ -n "$dir" ] || continue
  dest="$TARGET/$dir"

  # --- already a checkout: fast-forward it ---------------------------------
  if [ -d "$dest/.git" ]; then
    if [ "$pull" = no ]; then
      printf '    %-40s present\n' "$dir"
      skipped=$((skipped + 1))
      continue
    fi
    if [ "$mode" = check ]; then
      printf '    %-40s would be pulled\n' "$dir"
      skipped=$((skipped + 1))
      continue
    fi
    # --ff-only: git refuses rather than merging or rewriting, so a checkout
    # with local commits or a dirty tree is reported instead of disturbed.
    if out="$(git -C "$dest" pull --ff-only 2>&1)"; then
      printf '    %-40s up to date\n' "$dir"
      updated=$((updated + 1))
    else
      printf '    %-40s could not fast-forward\n' "$dir"
      printf '%s\n' "$out" | sed 's/^/        /'
      failed+=("$dir")
    fi
    continue
  fi

  # --- something else is in the way ----------------------------------------
  if [ -e "$dest" ]; then
    warn "$dest exists but is not a git checkout — leaving it alone"
    skipped=$((skipped + 1))
    continue
  fi

  # --- clone ---------------------------------------------------------------
  if [ "$mode" = check ]; then
    printf '    %-40s would be cloned from %s\n' "$dir" "$url"
    cloned=$((cloned + 1))
    continue
  fi

  printf '    %-40s cloning…\n' "$dir"
  if out="$(git clone --quiet "$url" "$dest" 2>&1)"; then
    cloned=$((cloned + 1))
  else
    printf '%s\n' "$out" | sed 's/^/        /'
    failed+=("$dir")
    # git leaves a partial directory behind on some failures; without this the
    # next run would see it and report "not a git checkout" forever.
    [ -d "$dest" ] && [ ! -d "$dest/.git" ] && rmdir "$dest" 2>/dev/null
  fi
done <<< "$REPOS"

# --- summary ----------------------------------------------------------------

echo
if [ "$mode" = check ]; then
  info "$cloned to clone, $skipped already present"
  exit 0
fi

info "$cloned cloned, $updated already checked out, $skipped skipped"

if [ ${#failed[@]} -gt 0 ]; then
  warn "failed: ${failed[*]}"
  # Every repo here is a private one over SSH, so a fresh machine with no key
  # loaded fails all of them at once and this is almost always the reason.
  warn "If these are authentication errors, check: ssh -T git@github.com"
  exit 1
fi

info "Done. cd $TARGET"
