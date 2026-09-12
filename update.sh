#!/usr/bin/env bash
#
# Bring this machine up to date with the config in this repo.
#
#   ./update.sh                 # Homebrew + core packages + zsh
#   ./update.sh dev privat      # …plus the named brew profiles
#
# Safe to run any time: every step is idempotent, so the first run on a new
# machine installs everything and later runs only apply what has changed.

set -euo pipefail
DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installs Homebrew first if this machine does not have it yet.
"$DAVCONF_DIR/brew/update.sh" "$@"

# brew/update.sh runs in its own process, so a Homebrew it just installed is
# not on our $PATH. Load it here too, or zsh/update.sh would not find brew.
if ! command -v brew >/dev/null; then
  for prefix in /opt/homebrew /usr/local; do
    [ -x "$prefix/bin/brew" ] && eval "$("$prefix/bin/brew" shellenv)" && break
  done
fi

"$DAVCONF_DIR/zsh/update.sh"
