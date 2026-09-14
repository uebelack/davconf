#!/usr/bin/env bash
#
# Install or update Homebrew packages from the Brewfiles in this directory.
# Safe to run any time; missing packages are added, the rest left alone.
#
#   ./brew/update.sh                 # common + this machine's profiles
#   ./brew/update.sh dev cloud       # common + the named profiles (ignores the file)
#   ./brew/update.sh --all           # common + every profile
#   ./brew/update.sh --list          # which profiles exist, which are selected
#   ./brew/update.sh --check         # report what is missing, install nothing
#   ./brew/update.sh --upgrade       # also upgrade every outdated formula
#
# Which profiles a machine gets is machine-local, not committed: it lives in
# ~/.config/davconf/profiles, one name per line. Brewfile.common is always
# applied on top of whatever is selected.
#
# brew bundle only installs what is missing. --upgrade additionally runs a full
# `brew upgrade` of every formula; casks are reported but never upgraded, since
# that needs a password the unattended daily run cannot supply. The daily
# auto-update passes --upgrade.

set -euo pipefail

BREW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/davconf/profiles"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

# Every Brewfile.<name> except the always-on common one.
available_profiles() {
  local f
  for f in "$BREW_DIR"/Brewfile.*; do
    local name="${f##*Brewfile.}"
    [ "$name" = common ] || printf '%s\n' "$name"
  done
}

# Selected profiles for this machine. Blank lines and # comments ignored.
selected_profiles() {
  [ -f "$PROFILES_FILE" ] || return 0
  sed -E 's/#.*//; s/[[:space:]]+//g' "$PROFILES_FILE" | grep -v '^$' || true
}

# Written on first run so there is something to edit rather than a blank page.
seed_profiles_file() {
  [ -f "$PROFILES_FILE" ] && return 0
  mkdir -p "$(dirname "$PROFILES_FILE")"
  {
    echo "# Which Brewfile profiles this machine gets, one per line."
    echo "# Brewfile.common is always applied and does not belong here."
    echo "#"
    echo "# Uncomment what this machine is for:"
    local p
    for p in $(available_profiles); do echo "# $p"; done
  } > "$PROFILES_FILE"
  warn "Created $PROFILES_FILE — no profiles selected yet, installing common only."
}

mode=install
upgrade=no
all=no
args_profiles=()

for arg in "$@"; do
  case "$arg" in
    --all)     all=yes ;;
    --check)   mode=check ;;
    --upgrade) upgrade=yes ;;
    --list)    mode=list ;;
    -h|--help) sed -n '/^# Install/,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "unknown option: $arg" >&2; exit 1 ;;
    *)         args_profiles+=("$arg") ;;
  esac
done

if [ "$mode" = list ]; then
  seed_profiles_file
  selected="$(selected_profiles | tr '\n' ' ')"
  info "Profiles in $BREW_DIR"
  echo "    common               always applied"
  for p in $(available_profiles); do
    case " $selected " in
      *" $p "*) printf '    %-20s selected\n' "$p" ;;
      *)        printf '    %-20s \033[2m-\033[0m\n' "$p" ;;
    esac
  done
  echo
  info "Selection for this machine: $PROFILES_FILE"
  exit 0
fi

if ! command -v brew >/dev/null; then
  info "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # A fresh install is not on $PATH yet — the installer only prints the
  # shellenv line for the user to add. Load it so the brew calls below work.
  for prefix in /opt/homebrew /usr/local; do
    if [ -x "$prefix/bin/brew" ]; then
      eval "$("$prefix/bin/brew" shellenv)"
      break
    fi
  done

  command -v brew >/dev/null || { echo "Homebrew install failed" >&2; exit 1; }
fi

# --- where casks go ---------------------------------------------------------
# A managed machine — a work Mac under MDM, typically — does not let you write
# to /Applications, and every cask install fails on the copy at the very end.
# Homebrew appends HOMEBREW_CASK_OPTS to every cask command, so pointing it at
# ~/Applications is the whole fix: macOS treats that as a real application
# directory, Spotlight indexes it and Launchpad lists it.
#
# The writability test is the entire condition, so there is no per-machine flag
# to remember and nothing changes on a machine where /Applications is writable.
# zsh/zprofile repeats it for `brew install --cask` typed by hand; this copy is
# here because the daily background update never reads a login shell.
#
# An HOMEBREW_CASK_OPTS already in the environment is left alone — if you have
# set one, it is more specific than this guess.
if [ ! -w /Applications ] && [ -z "${HOMEBREW_CASK_OPTS:-}" ]; then
  export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
  mkdir -p "$HOME/Applications"
  info "/Applications is not writable — installing casks into ~/Applications"
fi

# Explicit arguments win over the machine's file; --all wins over both.
profiles=()
if [ "$all" = yes ]; then
  while IFS= read -r p; do profiles+=("$p"); done < <(available_profiles)
elif [ ${#args_profiles[@]} -gt 0 ]; then
  profiles=("${args_profiles[@]}")
else
  seed_profiles_file
  while IFS= read -r p; do [ -n "$p" ] && profiles+=("$p"); done < <(selected_profiles)
fi

# common first, then each selected profile.
files=("$BREW_DIR/Brewfile.common")
for p in ${profiles[@]+"${profiles[@]}"}; do
  f="$BREW_DIR/Brewfile.$p"
  if [ ! -f "$f" ]; then
    echo "no such profile: $p (try: $(available_profiles | tr '\n' ' '))" >&2
    exit 1
  fi
  files+=("$f")
done

# brew bundle only ever installs what is missing. Upgrading is the separate
# `brew upgrade --formula` step below, so that casks are never upgraded
# automatically: a cask upgrade runs `sudo rm` to remove the old app, which
# cannot work from the unattended daily run where there is no tty for the
# password. Dropping --no-upgrade here would quietly reintroduce that.
bundle_args=(--no-upgrade)

# The greeting caches the outdated count. Drop it however this script exits —
# including a failure part-way through — so the next terminal never reports a
# figure from before the upgrade.
if [ "$upgrade" = yes ] && [ "$mode" = install ]; then
  trap 'rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/davconf/cache-brew-outdated"' EXIT
fi

# A profile that fails must not take the rest of the run down with it: the
# remaining profiles, the upgrade step and the zsh module all still matter.
# Failures are collected and reported, and the script exits non-zero at the end.
failed_profiles=()

for f in "${files[@]}"; do
  name="$(basename "$f")"
  if [ "$mode" = check ]; then
    info "Checking $name"
    # --no-upgrade: report what is absent, not what is merely outdated.
    brew bundle check --verbose --no-upgrade --file="$f" || true
  else
    info "Installing $name"
    brew bundle install "${bundle_args[@]}" --file="$f" || {
      warn "$name had failures — continuing"
      failed_profiles+=("$name")
    }
  fi
done

# brew bundle --upgrade only touches packages named in a Brewfile, which leaves
# their dependencies behind — most of what `brew outdated` reports. Upgrade
# everything so the count actually trends to zero.
#
# Formulae only: upgrading casks can need a password, and this runs unattended
# from the daily auto-update where there is no terminal to type one into.
if [ "$upgrade" = yes ] && [ "$mode" = install ]; then
  outdated="$(brew outdated --formula --quiet | wc -l | tr -d ' ')"
  if [ "$outdated" -gt 0 ]; then
    info "Upgrading $outdated outdated formulae"
    brew upgrade --formula
  else
    info "All formulae up to date"
  fi
  casks="$(brew outdated --cask --quiet | wc -l | tr -d ' ')"
  [ "$casks" -gt 0 ] && warn "$casks casks are outdated — upgrade them with: brew upgrade --cask"

fi

if [ ${#failed_profiles[@]} -gt 0 ]; then
  warn "Finished with failures in: ${failed_profiles[*]}"
  exit 1
fi

info "Done."
