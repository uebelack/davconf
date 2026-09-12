#!/usr/bin/env bash
#
# Bring this machine up to date with the config in this repo.
#
#   ./update.sh                 # Homebrew + this machine's packages + zsh
#                               #   + the macOS system tweaks
#   ./update.sh dev cloud       # …with the named brew profiles instead of
#                               #   the ones in ~/.config/davconf/profiles
#   ./update.sh --no-pull       # skip the git pull
#
# Safe to run any time: every step is idempotent, so the first run on a new
# machine installs everything and later runs only apply what has changed.
# zsh/autoupdate.zsh runs this once a day in the background.

set -euo pipefail
DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

args=()
pull=yes
for arg in "$@"; do
  case "$arg" in
    --no-pull) pull=no ;;
    *)         args+=("$arg") ;;
  esac
done

# --- pick up config committed on another machine -----------------------------
# Only fast-forward, and only with a clean tree: this must never touch work in
# progress. Anything unusual is reported and skipped, not forced.
if [ "$pull" = yes ] && [ -d "$DAVCONF_DIR/.git" ]; then
  if ! git -C "$DAVCONF_DIR" diff --quiet HEAD 2>/dev/null; then
    warn "Working tree has uncommitted changes — skipping git pull."
  elif ! git -C "$DAVCONF_DIR" pull --ff-only --quiet 2>/dev/null; then
    warn "Could not fast-forward — skipping git pull (diverged or offline?)."
  else
    info "Repo up to date ($(git -C "$DAVCONF_DIR" log -1 --format=%h))"
  fi
fi

# Installs Homebrew first if this machine does not have it yet.
"$DAVCONF_DIR/brew/update.sh" ${args+"${args[@]}"}

# brew/update.sh runs in its own process, so a Homebrew it just installed is
# not on our $PATH. Load it here too, or zsh/update.sh would not find brew.
if ! command -v brew >/dev/null; then
  for prefix in /opt/homebrew /usr/local; do
    [ -x "$prefix/bin/brew" ] && eval "$("$prefix/bin/brew" shellenv)" && break
  done
fi

"$DAVCONF_DIR/zsh/update.sh"

# macOS system defaults. No-op on anything else, and a no-op here too unless a
# setting has actually drifted — it restarts only the apps whose settings changed.
"$DAVCONF_DIR/mac/update.sh"
