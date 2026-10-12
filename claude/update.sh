#!/usr/bin/env bash
#
# Link this repo's agent skills into place.
#
#   ./claude/update.sh          # link ~/.claude/skills and ~/.agents/skills
#   ./claude/update.sh --check  # report what would change, change nothing
#
# Safe to run any time: a link that already points here is left alone, a link
# pointing elsewhere is replaced, and an existing real directory is backed up
# rather than clobbered.
#
# --- why two links ----------------------------------------------------------
# Claude Code reads ~/.claude/skills. But this machine already kept the skills
# at ~/.agents/skills, with ~/.claude/skills as a symlink onto it, and that is
# not an accident worth undoing: ~/.agents is the cross-tool location, and
# ~/.agents/.skill-lock.json lists the thirteen other agent CLIs that were
# selected to read from it. Pointing only ~/.claude/skills at this repo would
# quietly cut the rest of them off.
#
# So both paths are linked, as siblings, to the one directory in this repo.
# Not a chain — ~/.claude/skills -> ~/.agents/skills -> repo would work, but
# then one broken link in the middle breaks a path that looks fine from the
# end, and repairing it means knowing which of the two to look at. Two
# independent links are each checked and fixed on their own.
#
# --- what is not here -------------------------------------------------------
# .skill-lock.json stays machine-local and out of this repo. It is two things
# at once: provenance for the skills installed from GitHub, which would be
# worth committing, and UI state — a dismissed prompt, the list of agents last
# selected — which is per-machine and would conflict on every pull. The skills
# themselves work without it; it is the installer's bookkeeping, not an input
# to Claude Code.
#
# Nothing else under ~/.claude is touched. settings.json names machine-specific
# paths and hook scripts, plugins/ is marketplace-managed, and the rest is
# session state, history and caches.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check)   mode=check ;;
    -h|--help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

src="$DAVCONF_DIR/claude/skills"

# A symlink and a real directory are not the same problem. A link holds no
# data, so a wrong one is replaced and said so; a real directory is somebody's
# skills and is moved aside rather than removed.
link_skills() {
  local dest="$1" label="$2" verb=linked

  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      printf '    %-24s already linked\n' "$label"
      return 0
    fi
    if [ "$mode" = check ]; then
      warn "$dest points at $(readlink "$dest") — would be relinked to $src"
      return 0
    fi
    # Reported as one line at the end rather than two here, with what it used
    # to point at — the chain this repo replaces, ../.agents/skills, is the
    # thing worth seeing.
    verb="relinked (was $(readlink "$dest"))"
    rm "$dest"
  elif [ -e "$dest" ]; then
    if [ "$mode" = check ]; then
      warn "$dest would be backed up and replaced with a link to $src"
      return 0
    fi
    warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  else
    if [ "$mode" = check ]; then
      warn "$dest would be linked to $src"
      return 0
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  printf '    %-24s %s\n' "$label" "$verb"
}

info "Linking agent skills"

# The source has to exist before anything points at it, or both links are
# created dangling and every agent reads an empty skill set without saying so.
if [ ! -d "$src" ]; then
  warn "$src does not exist — nothing to link."
  exit 1
fi

link_skills "$HOME/.claude/skills" "~/.claude/skills"
link_skills "$HOME/.agents/skills" "~/.agents/skills"

if [ "$mode" = apply ]; then
  count="$(find "$src" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  info "$count skill(s) available."
fi
