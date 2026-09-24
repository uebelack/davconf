#!/usr/bin/env bash
#
# Link this repo's Neovim configuration into place and install its plugins.
#
#   ./nvim/update.sh          # link ~/.config/nvim, then install missing plugins
#   ./nvim/update.sh --check  # report what would change, change nothing
#
# Safe to run any time: the link is created only when it is missing or points
# somewhere else, an existing real directory is backed up rather than
# clobbered, and the plugin step only ever installs what is absent.
#
# This links the whole directory, not a single file the way ghostty/ and
# aerospace/ do, because a Neovim config is a tree — init.lua plus everything
# under lua/ — and linking the entries one by one would mean this script had
# to be edited every time a file is added. Linking the directory also puts
# lazy-lock.json inside the repo, which is where it belongs: it pins the exact
# plugin commits, so every machine ends up running the same ones.
#
# Plugins themselves live in ~/.local/share/nvim/lazy and are not this repo's
# business. lazy.nvim bootstraps itself on first start — see nvim/config/init.lua.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check) mode=check ;;
    *)       echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

src="$DAVCONF_DIR/nvim/config"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

info "Linking Neovim configuration"

if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
  printf '    %-24s already linked\n' "nvim"
elif [ "$mode" = check ]; then
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "$dest would be backed up and replaced with a link to $src"
  else
    warn "$dest would be linked to $src"
  fi
else
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  fi
  ln -s "$src" "$dest"
  printf '    %-24s linked\n' "nvim"
fi

# --- lombok ------------------------------------------------------------------
# jdtls cannot see anything Lombok generates unless Lombok is loaded into the
# language server's own JVM as an agent. Without it every `@Data`, `@Getter`,
# `@Builder` and `@Slf4j` class is reported as missing the methods it is
# annotated to have — a file full of red that compiles perfectly with Maven.
#
# It has to be a jar on disk rather than the one Maven already resolved into
# ~/.m2: the agent is a JVM argument, fixed when jdtls starts, and jdtls starts
# before it knows which project it is about to open. So one copy, pinned, used
# by every project. Lombok's agent is deliberately version-tolerant about the
# code it processes, which is what makes that safe.
#
# Not a Homebrew entry because there is no Lombok formula, and not a mason
# package because mason does not carry it either. This is the download, on the
# same terms as everything else here: fetched when it is missing, never
# replaced behind your back. Bump LOMBOK_VERSION to update it.
LOMBOK_VERSION=1.18.48
LOMBOK_JAR="${XDG_DATA_HOME:-$HOME/.local/share}/java/lombok.jar"
LOMBOK_URL="https://repo1.maven.org/maven2/org/projectlombok/lombok/$LOMBOK_VERSION/lombok-$LOMBOK_VERSION.jar"

info "Installing Lombok for jdtls"

if [ -f "$LOMBOK_JAR" ]; then
  printf '    %-24s already installed\n' "lombok.jar"
elif [ "$mode" = check ]; then
  warn "$LOMBOK_JAR would be downloaded ($LOMBOK_VERSION)"
else
  mkdir -p "$(dirname "$LOMBOK_JAR")"
  # Downloaded beside the target and moved into place, so an interrupted run
  # leaves no half-written jar for jdtls to fail on at the next start.
  tmp="$LOMBOK_JAR.part"
  if curl -fsSL --max-time 120 -o "$tmp" "$LOMBOK_URL" && unzip -tqq "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$LOMBOK_JAR"
    printf '    %-24s %s\n' "lombok.jar" "$LOMBOK_VERSION"
  else
    rm -f "$tmp"
    # Offline, or Maven Central having a day. Java still works; Lombok classes
    # are the part that will be wrong, and the next run fixes it.
    warn "could not download $LOMBOK_URL — Lombok-generated methods will show as errors"
  fi
fi

# --- plugins -----------------------------------------------------------------
# `Lazy! install` only clones what is missing, at the commit in lazy-lock.json
# when there is one. It deliberately does not update: this runs unattended once
# a day, and plugins silently moving underneath a working machine is exactly
# what the committed lockfile exists to prevent. Updating is a thing you do on
# purpose — `:Lazy update`, then commit nvim/config/lazy-lock.json.
if [ "$mode" = check ]; then
  exit 0
fi

if ! command -v nvim >/dev/null; then
  # First run on a fresh machine reaches here before brew has finished, or on
  # a machine that skipped it. Not a failure — the next run picks it up.
  info "nvim is not installed yet — plugins will be installed on the next run."
  exit 0
fi

info "Installing Neovim plugins"
if out="$(nvim --headless "+Lazy! install" +qa 2>&1)"; then
  printf '    %-24s up to date\n' "lazy.nvim"
else
  # Offline, or GitHub having a day. The config still works, just without the
  # plugins that did not clone, so this reports rather than stops the run.
  warn "nvim --headless '+Lazy! install' failed:"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
