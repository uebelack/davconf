#!/usr/bin/env bash
#
# Install or update Homebrew packages from the Brewfiles in this directory.
# Safe to run any time; missing packages are added, the rest left alone.
#
#   ./brew/update.sh                 # core only (brew/Brewfile)
#   ./brew/update.sh dev privat      # core + Brewfile.dev + Brewfile.privat
#   ./brew/update.sh --all           # every Brewfile in this directory
#   ./brew/update.sh --check dev     # report what is missing, install nothing
#   ./brew/update.sh --upgrade       # also upgrade every outdated formula
#
# Homebrew itself is installed first if it is missing.
#
# Brewfile           always installed — core packages for every machine
# Brewfile.zsh       shell dependencies (zsh/update.sh installs these itself)
# Brewfile.dev       development toolchains, cloud CLIs, GUI dev tools
# Brewfile.privat    personal machines only
#
# Missing packages are installed; already-installed ones are left at their
# current version unless --upgrade is given, which additionally runs a full
# `brew upgrade` of all formulae. The daily auto-update passes --upgrade.

set -euo pipefail

BREW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

# --- homebrew itself ---------------------------------------------------------

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

mode=install
upgrade=no
profiles=()

for arg in "$@"; do
  case "$arg" in
    --all)     for f in "$BREW_DIR"/Brewfile.*; do profiles+=("${f##*Brewfile.}"); done ;;
    --check)   mode=check ;;
    --upgrade) upgrade=yes ;;
    -h|--help) sed -n '/^# Install/,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "unknown option: $arg" >&2; exit 1 ;;
    *)         profiles+=("$arg") ;;
  esac
done

# Without --upgrade, only install what is missing. brew bundle otherwise
# upgrades every outdated package in the file as a side effect.
bundle_args=()
[ "$upgrade" = yes ] || bundle_args+=(--no-upgrade)

# Core first, then each requested profile.
files=("$BREW_DIR/Brewfile")
for p in ${profiles+"${profiles[@]}"}; do
  f="$BREW_DIR/Brewfile.$p"
  [ -f "$f" ] || { echo "no such Brewfile: $f" >&2; exit 1; }
  files+=("$f")
done

for f in "${files[@]}"; do
  name="$(basename "$f")"
  if [ "$mode" = check ]; then
    info "Checking $name"
    # --no-upgrade: report what is absent, not what is merely outdated.
    brew bundle check --verbose --no-upgrade --file="$f" || true
  else
    info "Installing $name"
    # ${a[@]+…}: on bash 3.2 (what macOS ships) an empty array under `set -u`
    # is an unbound variable, and bundle_args is empty whenever --upgrade is on.
    brew bundle install ${bundle_args[@]+"${bundle_args[@]}"} --file="$f"
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

info "Done."
