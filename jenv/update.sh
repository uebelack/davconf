#!/usr/bin/env bash
#
# Register every JDK on this machine with jenv.
#
#   ./jenv/update.sh           # add any JDK jenv does not know yet
#   ./jenv/update.sh --check   # list what would be added, add nothing
#
# Homebrew installs JDKs in two different shapes and jenv is told about
# neither automatically:
#
#   casks     /Library/Java/JavaVirtualMachines/<name>.jdk/Contents/Home
#             e.g. temurin@25 — these at least show up in `java_home -V`
#   formulae  $(brew --prefix)/opt/openjdk*/libexec/openjdk.jdk/Contents/Home
#             e.g. openjdk@21 — invisible to java_home unless hand-symlinked
#
# Run from update.sh straight after brew, so a JDK installed by a Brewfile is
# usable through jenv in the same run. Safe to run any time: a JDK already
# registered is left alone.

set -euo pipefail

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check)   mode=check ;;
    -h|--help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

if ! command -v jenv >/dev/null; then
  info "jenv is not installed — skipping."
  exit 0
fi

JENV_VERSIONS="${JENV_ROOT:-$HOME/.jenv}/versions"

# Symlinks resolve differently from the paths we hand to jenv, so both sides of
# the comparison are fully resolved before matching.
resolve() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

# What jenv already points at, one resolved path per line.
registered=""
if [ -d "$JENV_VERSIONS" ]; then
  for link in "$JENV_VERSIONS"/*; do
    [ -e "$link" ] || continue
    registered="$registered$(resolve "$link")
"
  done
fi

# Candidate JDK homes. The Homebrew ones are deliberately the stable
# opt/ paths rather than the Cellar directory they resolve to: the Cellar path
# contains the version number and stops existing the moment the formula is
# upgraded, which would leave jenv pointing at nothing.
candidates=()
for jdk in /Library/Java/JavaVirtualMachines/*/Contents/Home; do
  [ -x "$jdk/bin/java" ] && candidates+=("$jdk")
done
if command -v brew >/dev/null; then
  for jdk in "$(brew --prefix)"/opt/openjdk*/libexec/openjdk.jdk/Contents/Home; do
    [ -x "$jdk/bin/java" ] && candidates+=("$jdk")
  done
fi

if [ ${#candidates[@]} -eq 0 ]; then
  warn "No JDKs found on this machine."
  exit 0
fi

added=0
for jdk in "${candidates[@]}"; do
  version="$("$jdk/bin/java" -version 2>&1 | head -1 | sed -E 's/.*version "([^"]+)".*/\1/')"
  # Name it after what installed it: the cask directory (temurin-25.jdk) or,
  # for a formula, the formula itself — every one of those is called
  # "openjdk.jdk" on disk, which tells you nothing when several are installed.
  case "$jdk" in
    */opt/*/libexec/openjdk.jdk/*) label="$(basename "${jdk%%/libexec/*}")" ;;
    *)                             label="$(basename "$(dirname "$(dirname "$jdk")")")" ;;
  esac
  label="$label $version"

  case "
$registered" in
    *"
$(resolve "$jdk")
"*)
      printf '    %-46s already registered\n' "$label"
      continue
      ;;
  esac

  if [ "$mode" = check ]; then
    printf '    %-46s \033[1;33mwould add\033[0m\n' "$label"
    continue
  fi

  if jenv add "$jdk" >/dev/null 2>&1; then
    printf '    %-46s \033[1;32madded\033[0m\n' "$label"
    added=$((added + 1))
  else
    printf '    %-46s \033[1;31mfailed\033[0m\n' "$label"
  fi
done

if [ "$mode" = check ]; then
  info "Check only — nothing was changed."
elif [ "$added" -gt 0 ]; then
  # jenv keeps a cache of each version's javac/java paths; without this the
  # newly added JDKs are listed but not selectable until the next rehash.
  jenv rehash 2>/dev/null || true
  info "Added $added JDK(s). Use them with: jenv global <version>"
fi
