#!/usr/bin/env bash
#
# Bootstrap this machine.
#
#   ./install.sh                 # Homebrew + core packages + zsh
#   ./install.sh dev personal    # …plus the named brew profiles
#
# Every step is idempotent: re-running updates rather than reinstalls.

set -euo pipefail
DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v brew >/dev/null || "$DAVCONF_DIR/install_basis.sh"
"$DAVCONF_DIR/brew/install.sh" "$@"
"$DAVCONF_DIR/zsh/install.sh"
