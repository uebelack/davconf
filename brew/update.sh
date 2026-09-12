#!/usr/bin/env bash
#
# Install or update Homebrew packages from the Brewfiles in this directory.
# Safe to run any time; missing packages are added, the rest left alone.
#
#   ./brew/update.sh                 # common + this machine's profiles
#   ./brew/update.sh java ruby       # common + the named profiles (ignores the file)
#   ./brew/update.sh --all           # common + every profile
#   ./brew/update.sh --list          # which profiles exist, which are selected
#   ./brew/update.sh --check         # report what is missing, install nothing
#   ./brew/update.sh --upgrade       # also upgrade every outdated formula
#
# Which profiles a machine gets is machine-local, not committed: it lives in
# ~/.config/davconf/profiles, one name per line. Brewfile.common is always
# applied on top of whatever is selected.
#
# Missing packages are installed; already-installed ones are left at their
# current version unless --upgrade is given, which additionally runs a full
# `brew upgrade` of all formulae. The daily auto-update passes --upgrade.

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

# Without --upgrade, only install what is missing. brew bundle otherwise
# upgrades every outdated package in the file as a side effect.
bundle_args=()
[ "$upgrade" = yes ] || bundle_args+=(--no-upgrade)

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
