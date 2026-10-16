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

# --- version -----------------------------------------------------------------
# This configuration is not version-agnostic and cannot be made so. lsp.lua
# builds on vim.lsp.config(), which arrived in 0.11; before 0.8, vim.cmd is a
# plain function rather than a callable table, so init.lua itself fails on
# `vim.cmd.colorscheme`. Both of those are errors in Lua at startup, and what
# you get is a traceback pointing into this repo — which reads as the config
# being broken rather than the binary being too old.
#
# So check it here and say the one thing worth saying. Nothing below is skipped
# on account of it: the config is linked either way, because the config is not
# what is wrong and a newer nvim will find it already in place.
NVIM_MIN=0.11.0

nvim_version() {
  # `NVIM v0.11.5`, or `NVIM v0.12.0-dev-1234+gabc` on a nightly — take the
  # three numbers and ignore whatever the build appends.
  nvim --version 2>/dev/null | head -1 |
    sed -E 's/^NVIM v?([0-9]+(\.[0-9]+){0,2}).*/\1/' || true
}

# True when A is older than B. Field by field as integers, rather than with
# `sort -V`: BSD sort — the one on the Macs — does not have it. A missing field
# counts as 0, so "0.11" and "0.11.0" compare equal.
version_lt() {
  local IFS=. i x y
  local -a av bv
  av=($1) bv=($2)
  for i in 0 1 2; do
    # Strip anything non-numeric a pre-release suffix left behind ("0-dev"),
    # which would otherwise make -lt fail rather than compare.
    x="${av[i]:-0}"; y="${bv[i]:-0}"
    x="${x%%[^0-9]*}"; y="${y%%[^0-9]*}"
    [ "${x:-0}" -lt "${y:-0}" ] && return 0
    [ "${x:-0}" -gt "${y:-0}" ] && return 1
  done
  return 1
}

nvim_too_old=no
if command -v nvim >/dev/null; then
  info "Checking the Neovim version"
  have="$(nvim_version)"
  if [ -z "$have" ]; then
    warn "could not read a version out of \`nvim --version\` — assuming it is new enough."
  elif version_lt "$have" "$NVIM_MIN"; then
    nvim_too_old=yes
    warn "Neovim $have is too old for this config, which needs $NVIM_MIN or newer."
    warn "Until it is upgraded, nvim will fail at startup with a Lua traceback"
    warn "pointing into nvim/config — the config is fine, the binary is not."
    case "$(uname -s)" in
      Darwin) warn "  brew upgrade neovim" ;;
      *)      warn "  check apt/Packages — Neovim comes from a PPA there, because"
              warn "  Ubuntu's own build is far too old. See the README." ;;
    esac
  else
    printf '    %-24s %s\n' "nvim" "$have"
  fi
fi

# --- the C toolchain ---------------------------------------------------------
# nvim-treesitter builds every parser from C source on the machine it runs on.
# When the toolchain cannot link, you do not find out here — you find out as
# twenty-five "Error during compilation" dialogs inside nvim, each one waiting
# for you to press ENTER, with a linker error that names an SDK file and says
# nothing about what to do.
#
# The failure worth catching is specifically *linking*, not "is there a
# compiler". A stale Command Line Tools install has a working clang and an `ld`
# older than the SDK beside it: on macOS 27 the .tbd stubs declare arm64e.x1
# targets, an older ld does not know that spelling, and it rejects a valid file
# as malformed. clang --version looks perfect throughout. So the probe compiles
# *and links* a real binary, because that is the step that breaks.
#
# $CC first, then the same order nvim-treesitter itself tries — otherwise this
# could pass with cc while the parser build picks something else and fails.
toolchain_broken=no

ts_cc=""
for candidate in ${CC:-} cc gcc clang; do
  [ -n "$candidate" ] || continue
  if command -v "$candidate" >/dev/null; then ts_cc="$candidate"; break; fi
done

info "Checking the C toolchain (treesitter builds its parsers)"

if [ -z "$ts_cc" ]; then
  toolchain_broken=yes
  warn "No C compiler found — every treesitter parser will fail to build."
  case "$(uname -s)" in
    Darwin) warn "  xcode-select --install" ;;
    *)      warn "  the build-essential entry in apt/Packages covers this" ;;
  esac
else
  probe_dir="$(mktemp -d)"
  printf 'int main(void){return 0;}\n' > "$probe_dir/probe.c"
  if probe_out="$("$ts_cc" "$probe_dir/probe.c" -o "$probe_dir/probe" 2>&1)"; then
    printf '    %-24s %s\n' "$ts_cc" "compiles and links"
  else
    toolchain_broken=yes
    warn "$ts_cc cannot link a trivial program — every parser build will fail:"
    printf '%s\n' "$probe_out" | sed 's/^/    /' | head -12
    # The one this has actually been: the SDK is newer than the linker beside
    # it. Both halves come from the Command Line Tools, so they are only out of
    # step when that package is half-updated — which a macOS upgrade does.
    if [ "$(uname -s)" = Darwin ]; then
      warn "On macOS this is almost always a Command Line Tools install older than the SDK."
      warn "  xcode-select -p   # which toolchain is active"
      warn "  ld -v             # its linker version"
      warn "Then update it:"
      warn "  softwareupdate --list        # look for 'Command Line Tools'"
      warn "  sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install"
    fi
  fi
  rm -rf "$probe_dir"
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
  # First run on a fresh machine reaches here before the package module has
  # finished, or on a machine that skipped it. Not a failure — the next run
  # picks it up.
  info "nvim is not installed yet — plugins will be installed on the next run."
  exit 0
fi

# Running the plugin install against a too-old nvim buys a second copy of the
# same traceback and no plugins, so skip it and let the warning above stand as
# the result. Non-zero, because unlike a missing nvim this does not fix itself
# on the next run: update.sh names it at the end rather than looking clean.
if [ "$nvim_too_old" = yes ]; then
  warn "Skipping the plugin install until Neovim is new enough."
  exit 1
fi

if [ "$toolchain_broken" = yes ]; then
  warn "Installing plugins anyway — only the treesitter parsers need a compiler."
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

# Non-zero so the daily run names it rather than looking clean. A broken
# toolchain does not repair itself between runs, and the cost of not knowing is
# a dialog per parser every time a file of a new language is opened.
if [ "$toolchain_broken" = yes ]; then
  warn "The C toolchain is broken — treesitter parsers cannot build until it is fixed."
  exit 1
fi
