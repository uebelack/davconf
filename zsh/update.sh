#!/usr/bin/env bash
#
# Install or update the davconf zsh environment: oh-my-zsh, the spaceship
# theme, the custom plugins and the shared .zshrc. The tools the .zshrc hooks
# into (neovim, direnv, the version managers) come from brew/Brewfile.common
# and the language profiles; the .zshrc guards each one, so a machine missing
# any of them still gets a working shell. Safe to run any time —
# every step is idempotent, oh-my-zsh and the plugins are pulled to their
# latest version, and existing files are backed up rather than clobbered.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$ZSH_DIR/custom"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

# --- prerequisites ----------------------------------------------------------

command -v zsh >/dev/null || { echo "zsh is not installed" >&2; exit 1; }
command -v git >/dev/null || { echo "git is not installed" >&2; exit 1; }

# --- .zshrc -----------------------------------------------------------------

link_config() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    printf '    %-24s already linked\n' "$(basename "$dest")"
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    warn "backing up $dest -> $dest.$BACKUP_SUFFIX"
    mv "$dest" "$dest.$BACKUP_SUFFIX"
  fi
  ln -s "$src" "$dest"
  printf '    %-24s linked\n' "$(basename "$dest")"
}

info "Linking shell configuration"
link_config "$DAVCONF_DIR/zsh/zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.zfunctions"

# --- local secrets ----------------------------------------------------------

if [ ! -f "$HOME/.zshrc.local" ]; then
  info "Creating ~/.zshrc.local from template"
  cp "$DAVCONF_DIR/zsh/zshrc.local.example" "$HOME/.zshrc.local"
  chmod 600 "$HOME/.zshrc.local"
  warn "Fill in your API keys in ~/.zshrc.local — it is not part of this repo."
fi

# --- oh-my-zsh --------------------------------------------------------------

if [ -d "$ZSH_DIR/.git" ]; then
  info "Updating oh-my-zsh"
  git -C "$ZSH_DIR" pull --quiet --ff-only || warn "could not fast-forward oh-my-zsh"
elif [ -d "$ZSH_DIR" ]; then
  warn "$ZSH_DIR exists but is not a git checkout — leaving it alone"
else
  info "Installing oh-my-zsh"
  # ZSH is pinned explicitly: the upstream installer otherwise picks up an
  # exported $ZSH from the calling shell and installs into the wrong place.
  # --unattended: do not launch zsh; KEEP_ZSHRC leaves the symlink we just made.
  ZSH="$ZSH_DIR" RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# --- custom plugins and theme ----------------------------------------------

clone_or_update() {
  local repo="$1" dest="$2" name="$3"
  if [ -d "$dest/.git" ]; then
    printf '    %-24s updating…\n' "$name"
    git -C "$dest" pull --quiet --ff-only || warn "could not fast-forward $name"
  elif [ -e "$dest" ]; then
    warn "$dest exists but is not a git checkout — skipping $name"
  else
    printf '    %-24s cloning…\n' "$name"
    git clone --quiet --depth=1 "$repo" "$dest"
  fi
}

info "Installing zsh plugins and theme"
mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"
clone_or_update https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" zsh-autosuggestions
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting
clone_or_update https://github.com/spaceship-prompt/spaceship-prompt \
  "$ZSH_CUSTOM/themes/spaceship-prompt" spaceship-prompt

if [ ! -e "$ZSH_CUSTOM/themes/spaceship.zsh-theme" ]; then
  ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" \
        "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# --- default shell ----------------------------------------------------------

ZSH_PATH="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
  warn "Default shell is ${SHELL:-unknown}. Make zsh the default with:"
  warn "  chsh -s $ZSH_PATH"
fi

info "Done. Start a new shell or run: exec zsh"
