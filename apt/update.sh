#!/usr/bin/env bash
#
# Install or update the apt packages listed in apt/Packages — the Linux half of
# what brew/update.sh does for the Macs. Safe to run any time; missing packages
# are added, the rest left alone.
#
#   ./apt/update.sh            # install anything missing
#   ./apt/update.sh --list     # what the file asks for, and what is installed
#   ./apt/update.sh --check    # report what is missing, install nothing
#   ./apt/update.sh --upgrade  # also upgrade every outdated package
#
# There are no profiles, unlike brew/: the Ubuntu machine is one machine used
# one way, so apt/Packages is the whole list. The flags mirror brew/update.sh's
# because update.sh and the daily auto-update pass the same ones to whichever of
# the two this machine has.
#
# Installing needs root, which the daily background run cannot ask for — it has
# no terminal to type a password into. So: run as root, or give this user a
# password-free sudo, or accept that the unattended run reports what is missing
# and installs it the next time you run this by hand. It says which of those
# happened rather than failing silently.
#
# Packages are installed with --no-install-recommends. On a machine with no
# display the recommends of an innocent-looking package are how X11, a sound
# server and a font cache arrive; a headless box should stay headless, and
# anything actually needed is named in apt/Packages instead.

set -euo pipefail

APT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$APT_DIR/Packages"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/davconf"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=install
upgrade=no

for arg in "$@"; do
  case "$arg" in
    --check)   mode=check ;;
    --list)    mode=list ;;
    --upgrade) upgrade=yes ;;
    # Accepted and ignored so the same command line works on both platforms:
    # update.sh forwards its arguments to whichever package module this machine
    # has, and the brew ones are about profiles that do not exist here.
    --all)     ;;
    -h|--help) sed -n '/^# Install/,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "unknown option: $arg" >&2; exit 1 ;;
    *)         warn "ignoring '$arg' — apt/Packages has no profiles, see brew/ for those." ;;
  esac
done

if ! command -v apt-get >/dev/null; then
  info "Not an apt machine — skipping."
  exit 0
fi

[ -f "$PACKAGES_FILE" ] || { echo "no such file: $PACKAGES_FILE" >&2; exit 1; }

# --- the file ---------------------------------------------------------------
# Comments, trailing comments and blank lines out; ppa: lines separated from
# package names.
ppas=()
packages=()
while IFS= read -r entry; do
  case "$entry" in
    ppa:*) ppas+=("${entry#ppa:}") ;;
    *)     packages+=("$entry") ;;
  esac
done < <(sed -E 's/#.*//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$PACKAGES_FILE" | grep -v '^$')

# Prints nothing when the package is not installed. The `|| true` is not
# decoration: dpkg-query exits non-zero for a package it has never heard of,
# and under `set -o pipefail` that would take the whole script down from
# inside a command substitution.
installed_version() {
  dpkg-query -W -f='${db:Status-Status} ${Version}\n' "$1" 2>/dev/null |
    awk '$1 == "installed" { print $2 }' || true
}

# What apt would install, or nothing at all when this release does not carry
# the package. Needs package lists on disk to answer — see refresh_lists below.
candidate_version() {
  apt-cache policy "$1" 2>/dev/null |
    awk -F': ' '/^  Candidate:/ { print ($2 == "(none)" ? "" : $2) }' || true
}

if [ "$mode" = list ]; then
  info "Packages in $PACKAGES_FILE"
  for p in ${ppas[@]+"${ppas[@]}"}; do
    printf '    %-32s %s\n' "ppa:$p" "repository"
  done
  for p in ${packages[@]+"${packages[@]}"}; do
    v="$(installed_version "$p")"
    if [ -n "$v" ]; then printf '    %-32s %s\n' "$p" "$v"
    else                 printf '    %-32s \033[2mnot installed\033[0m\n' "$p"
    fi
  done
  exit 0
fi

# --- root -------------------------------------------------------------------
# Three ways to have it, in order of how little they ask of you. `sudo -n`
# covers both a NOPASSWD rule and a still-valid timestamp from earlier, which
# is what makes the daily background run work at all on a machine set up for it.
sudo_cmd=()
have_root=yes
if [ "$(id -u)" = 0 ]; then
  :
elif ! command -v sudo >/dev/null; then
  have_root=no
elif sudo -n true 2>/dev/null; then
  sudo_cmd=(sudo -n)
elif [ -t 0 ]; then
  sudo_cmd=(sudo)
else
  have_root=no
fi

as_root() { ${sudo_cmd[@]+"${sudo_cmd[@]}"} "$@"; }

# apt asks questions — a changed config file, a service to restart — and the
# daily run has nobody to answer them. DEBIAN_FRONTEND is what turns those into
# defaults, and it has to be set *past* sudo: sudo resets the environment, so
# exporting it in this shell would not reach apt-get at all.
apt_get() { as_root env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

if [ "$have_root" = no ] && [ "$mode" = install ]; then
  warn "No root and no terminal to ask for a password — reporting only."
  warn "Run ./apt/update.sh by hand, or give this user a password-free sudo."
  mode=check
fi

# --- package lists ----------------------------------------------------------
# `apt-cache policy` answers from the lists in /var/lib/apt/lists, so a machine
# that has never run `apt-get update` — a fresh container, typically — would
# report every package in the file as missing from the release. Refresh when
# there is no index at all, or when the newest one is over a day old.
lists_are_stale() {
  [ -d /var/lib/apt/lists ] || return 0
  [ -z "$(find /var/lib/apt/lists -maxdepth 1 -type f -name '*_Packages*' \
            -mtime -1 2>/dev/null | head -1)" ]
}

refresh_lists() {
  info "Refreshing package lists"
  apt_get update -qq
}

lists_refreshed=no
if lists_are_stale; then
  if [ "$have_root" = yes ]; then
    refresh_lists
    lists_refreshed=yes
  else
    warn "Package lists are stale and cannot be refreshed without root —"
    warn "what follows may be out of date."
  fi
fi

# --- PPAs -------------------------------------------------------------------
# Homebrew's taps, more or less. Only Ubuntu has them: a PPA is built against a
# specific Ubuntu release, so on Debian the whole mechanism is absent and the
# packages behind it come from the archive or not at all.
#
# add-apt-repository is idempotent but not cheap — it runs its own apt-get
# update every time — so the sources are grepped first. Both URL shapes are
# checked: Launchpad moved from ppa.launchpad.net to ppa.launchpadcontent.net,
# and a machine upgraded from an older release still has the old one.
is_ubuntu() {
  [ -r /etc/os-release ] || return 1
  grep -qE '^(ID|ID_LIKE)=.*ubuntu' /etc/os-release
}

ppa_present() {
  grep -rqsE "ppa\.launchpad(content)?\.net/$1(/|\s|$)" \
    /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null
}

if [ ${#ppas[@]} -gt 0 ]; then
  if ! is_ubuntu; then
    warn "Not Ubuntu — skipping ${#ppas[@]} PPA(s); their packages come from the archive or not at all."
  else
    info "Checking repositories"
    added=0
    for p in "${ppas[@]}"; do
      if ppa_present "$p"; then
        printf '    %-32s already added\n' "ppa:$p"
        continue
      fi
      if [ "$mode" = check ]; then
        # Nothing is added in check mode, so whatever this PPA carries has no
        # candidate version yet and is about to be listed as not in the
        # release. Say so here, or that line reads as a missing package.
        printf '    %-32s \033[1;33mwould be added — its packages show as "not in this release" until it is\033[0m\n' "ppa:$p"
        continue
      fi
      # add-apt-repository lives in software-properties-common, which a minimal
      # image does not have.
      if ! command -v add-apt-repository >/dev/null; then
        info "Installing software-properties-common for add-apt-repository"
        apt_get install -y -qq --no-install-recommends software-properties-common
      fi
      if as_root env DEBIAN_FRONTEND=noninteractive add-apt-repository -y "ppa:$p" >/dev/null 2>&1; then
        printf '    %-32s \033[1;32madded\033[0m\n' "ppa:$p"
        added=$((added + 1))
      else
        # A PPA with no build for this release, or no network. The packages it
        # was for are reported as unavailable below, which is the useful half.
        warn "could not add ppa:$p"
      fi
    done
    # add-apt-repository refreshes the lists itself, so this only covers the
    # case where it did not run.
    if [ "$added" -gt 0 ]; then
      lists_refreshed=yes
    fi
  fi
fi

# --- what is missing --------------------------------------------------------
missing=()
unavailable=()
for p in ${packages[@]+"${packages[@]}"}; do
  [ -n "$(installed_version "$p")" ] && continue
  if [ -n "$(candidate_version "$p")" ]; then
    missing+=("$p")
  else
    unavailable+=("$p")
  fi
done

if [ "$mode" = check ]; then
  info "Checking $(basename "$PACKAGES_FILE")"
  if [ ${#missing[@]} -eq 0 ]; then
    printf '    %s\n' "nothing to install"
  else
    for p in "${missing[@]}"; do printf '    %-32s \033[1;33mmissing\033[0m\n' "$p"; done
  fi
  for p in ${unavailable[@]+"${unavailable[@]}"}; do
    printf '    %-32s \033[1;31mnot in this release\033[0m\n' "$p"
  done
  exit 0
fi

# The greeting caches the upgradable count. Drop it however this script exits,
# including part-way through, so the next terminal never reports a figure from
# before the run.
trap 'rm -f "$STATE_DIR/cache-apt-outdated"' EXIT

# --- install ----------------------------------------------------------------
# One apt-get call rather than one per package: apt resolves the whole set
# together, which is both faster and how it avoids half-installing a group with
# a shared dependency.
failed=no
if [ ${#missing[@]} -eq 0 ]; then
  info "All packages present"
else
  info "Installing ${#missing[@]} package(s)"
  printf '    %s\n' "${missing[*]}"
  if ! apt_get install -y --no-install-recommends "${missing[@]}"; then
    warn "apt-get install failed — continuing"
    failed=yes
  fi
fi

if [ ${#unavailable[@]} -gt 0 ]; then
  warn "Not available in this release: ${unavailable[*]}"
fi

# --- fd ---------------------------------------------------------------------
# Debian renamed the binary to `fdfind`: there was already an `fd` in the
# archive, from fdclone. Telescope's find_files looks for `fd` and falls back to
# `find` without it — which does work, slowly, while looking like nothing is
# wrong. ~/.local/bin is on $PATH from zsh/zprofile, and the link is only made
# when there is no real `fd` to shadow.
if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  mkdir -p "$HOME/.local/bin"
  if [ ! -e "$HOME/.local/bin/fd" ]; then
    ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
    info "Linked ~/.local/bin/fd -> $(command -v fdfind)"
  fi
fi

# --- upgrade ----------------------------------------------------------------
# The daily auto-update passes --upgrade, so the count in the greeting trends to
# zero instead of growing forever.
#
# `upgrade` rather than `dist-upgrade`: this runs unattended, and dist-upgrade
# is allowed to remove packages to resolve a conflict. --with-new-pkgs is the
# part of it worth having — without it, a package whose new version needs a new
# dependency is held back and reported as outdated for ever.
#
# Nothing is ever removed here, autoremove included: an unattended run deciding
# a kernel or a library is no longer needed is not a thing this script should do
# behind your back. `sudo apt-get autoremove` by hand, when you are looking.
if [ "$upgrade" = yes ]; then
  [ "$lists_refreshed" = yes ] || refresh_lists
  outdated="$( { apt-get -s upgrade --with-new-pkgs 2>/dev/null || true; } |
                grep -c '^Inst ' | tr -d ' ' || true)"
  if [ "${outdated:-0}" -gt 0 ]; then
    info "Upgrading $outdated outdated package(s)"
    if ! apt_get upgrade -y --with-new-pkgs; then
      warn "apt-get upgrade failed — continuing"
      failed=yes
    fi
  else
    info "All packages up to date"
  fi
fi

[ "$failed" = yes ] && { warn "Finished with failures."; exit 1; }

info "Done."
