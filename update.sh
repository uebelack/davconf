#!/usr/bin/env bash
#
# Bring this machine up to date with the config in this repo.
#
#   ./update.sh                 # Homebrew + this machine's packages + zsh
#                               #   + the Ghostty config + the Chrome theme
#                               #   + the macOS system tweaks
#   ./update.sh dev cloud       # …with the named brew profiles instead of
#                               #   the ones in ~/.config/davconf/profiles
#   ./update.sh --no-pull       # skip the git pull (escape hatch, see below)
#
# Safe to run any time: every step is idempotent, so the first run on a new
# machine installs everything and later runs only apply what has changed.
# zsh/autoupdate.zsh runs this once a day in the background.
#
# The git pull always runs. Config committed on another machine only reaches
# this one through it, so a quietly skipped pull leaves the machine silently
# stale — which is the one failure this script exists to prevent. It is
# --ff-only, and that is what makes running it unconditionally safe: git
# refuses rather than rewriting history or overwriting a modified file. When
# the pull cannot happen, the run continues with the checked-out version and
# says so loudly, with git's own reason. --no-pull is the deliberate opt-out.

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
# This runs on every invocation. A dirty working tree is no longer a reason to
# skip it: --ff-only never rewrites history, and git aborts the pull by itself
# if an incoming change would overwrite a locally modified file. Guarding
# against that up front only meant a machine with one stray edit stopped
# receiving config updates entirely, without anyone noticing.
#
# Failure is never fatal — offline, no remote, diverged history — but it is
# always reported, with git's own message, so a machine that has stopped
# updating is visible in the log rather than looking like a clean run.
if [ "$pull" = no ]; then
  warn "Skipping the git pull (--no-pull) — this run may apply stale config."
elif [ "${DAVCONF_PULLED:-0}" = 1 ]; then
  : # already pulled by the run that re-executed us, see below
elif [ ! -d "$DAVCONF_DIR/.git" ]; then
  warn "$DAVCONF_DIR is not a git checkout — cannot pull, using it as it is."
else
  info "Pulling the latest config"
  before="$(git -C "$DAVCONF_DIR" rev-parse HEAD)"

  if pull_out="$(git -C "$DAVCONF_DIR" pull --ff-only 2>&1)"; then
    after="$(git -C "$DAVCONF_DIR" rev-parse HEAD)"
    if [ "$before" = "$after" ]; then
      info "Already current ($(git -C "$DAVCONF_DIR" log -1 --format='%h %s'))"
    else
      info "Updated to $(git -C "$DAVCONF_DIR" log -1 --format='%h %s')"

      # The pull just rewrote this file underneath a running bash, which reads
      # a script incrementally and would carry on at a now-meaningless byte
      # offset. Start over from the new version — nothing has run yet, so this
      # repeats no work. It cannot loop: the second run's pull finds nothing
      # new, and DAVCONF_PULLED skips its network round-trip anyway.
      info "Restarting with the updated update.sh"
      export DAVCONF_PULLED=1
      exec "$DAVCONF_DIR/update.sh" ${@+"$@"}
    fi
  else
    warn "git pull failed — continuing with the checked-out version:"
    printf '%s\n' "$pull_out" | sed 's/^/    /'
  fi
fi

# --- modules -----------------------------------------------------------------
# Every module runs, even when an earlier one failed. A third-party brew tap
# breaking upstream is not a reason for this machine's shell, terminal, browser
# and macOS settings to stop being updated — the same reasoning the git pull
# above already uses. Failures are collected, named at the end, and still make
# the whole run exit non-zero, so nothing is quietly swallowed.
failed=" "
run_module() {
  local name="$1"
  shift
  # The `if` is what suspends `set -e` for the call: without it the first
  # failing module would still take the whole script down.
  if "$DAVCONF_DIR/$name/update.sh" ${@+"$@"}; then
    return 0
  fi
  warn "$name/update.sh failed — continuing with the rest."
  failed="$failed$name "
}

# Installs Homebrew first if this machine does not have it yet.
run_module brew ${args+"${args[@]}"}

# brew/update.sh runs in its own process, so a Homebrew it just installed is
# not on our $PATH. Load it here too, or zsh/update.sh would not find brew.
if ! command -v brew >/dev/null; then
  for prefix in /opt/homebrew /usr/local; do
    [ -x "$prefix/bin/brew" ] && eval "$("$prefix/bin/brew" shellenv)" && break
  done
fi

# Straight after brew: a JDK a Brewfile just installed is registered with jenv
# in the same run, rather than sitting on disk unusable until noticed.
run_module jenv

run_module zsh

# Terminal configuration. Just a symlink, so it is cheap and cannot fail in a
# way that matters — but it goes after zsh, since the two are read together the
# next time a terminal opens.
run_module ghostty

# The browser, next to the terminal it shares a palette with. Builds the theme
# and reports it; loading it is a one-off manual step Chrome allows no way
# around, and the module goes quiet once a machine opts out or has it applied.
run_module chrome

# The editor, same palette again. Links the theme extension into VS Code and
# Cursor; picking it is a one-off per editor, in a settings.json this repo does
# not own.
run_module vscode

# macOS system defaults. No-op on anything else, and a no-op here too unless a
# setting has actually drifted — it restarts only the apps whose settings changed.
run_module mac

if [ "$failed" != " " ]; then
  warn "Finished with failures in:$failed"
  exit 1
fi
