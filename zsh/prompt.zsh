# Spaceship prompt, Synthwave '85 — the palette of ghostty/config and the
# greeting sun, on the prompt itself.
#
#   ╭─ ~/dev/davconf   main ✱  ⬢ 24.14.1              2.4s · 14:32
#   ╰─▸ git push
#
# Two lines on purpose: a deep path and a busy git status stay off the line you
# type on, so the command always starts in the same column. The right side is
# the stuff you only want after the fact — how long the last command took, and
# what time it finished.
#
# Sourced from zshrc *before* oh-my-zsh loads the theme. Every spaceship
# section declares its settings as ${VAR=default}, which assigns only when the
# variable is unset, so anything set here wins and anything left out keeps
# spaceship's own default. Setting them afterwards would be too late.
#
# Colours are 24-bit hex: zsh passes %F{#rrggbb} through untouched and Ghostty
# renders it. The two Nerd Font glyphs ( for git,  for the lock) come from
# the font in brew/Brewfile.common, with Ghostty's bundled symbol fallback
# behind them; everything else is plain Unicode that any font has.

# ── Palette ──────────────────────────────────────────────────────────────────
# Same hexes as ghostty/config, named for what they do here.
sw_neon=#f92aad        # the frame, the caret, anything structural
sw_cyan=#00f0ff        # where you are
sw_gold=#fede5d        # what branch you are on
sw_coral=#fe4450       # something is wrong
sw_lime=#72f1b8        # runtimes
sw_orange=#ff8b39      # clouds and infrastructure
sw_azure=#03edf9       # containers
sw_lilac=#d4c8ff       # people and packages
sw_dim=#495495         # the after-the-fact column

# ── Shape ────────────────────────────────────────────────────────────────────
SPACESHIP_PROMPT_ADD_NEWLINE=true      # room to breathe above each prompt
SPACESHIP_PROMPT_ASYNC=true            # git status never holds up the caret
SPACESHIP_PROMPT_PREFIXES_SHOW=true
SPACESHIP_PROMPT_SUFFIXES_SHOW=true
SPACESHIP_PROMPT_DEFAULT_PREFIX=""     # symbols instead of "on"/"via"/"at"
SPACESHIP_PROMPT_DEFAULT_SUFFIX=" "

# The opening corner of the frame. Spaceship suppresses the first section's
# prefix, so the corner cannot ride along on dir — it is its own section, which
# also keeps it correct when user@host appears in front of dir over ssh.
spaceship_neon_open() {
  spaceship::section --color "#f92aad" --symbol "╭─ "
}

# Git and language versions, nothing else. The cloud and container sections
# (aws, gcloud, kubectl, terraform, docker_context) are deliberately absent:
# what they report is rarely what the next command depends on, and every
# section left in the order is one more check per prompt, async or not. Adding
# one back is a line here plus its colour below.
SPACESHIP_PROMPT_ORDER=(
  neon_open      # ╭─
  user           # only over ssh
  host           # only over ssh
  dir            # where you are
  git            # branch + working tree state
  package        # version from package.json / Cargo.toml / …
  node
  bun
  dart
  python
  ruby
  golang
  rust
  java
  venv           # an activated python virtualenv
  jobs           # background jobs
  exit_code      # what the last command returned, when it was not 0
  line_sep       # ↵
  char           # ╰─▸
)

# The right side, one line up — see SPACESHIP_RPROMPT_ADD_NEWLINE in spaceship.
SPACESHIP_RPROMPT_ORDER=(
  exec_time
  time
)

# ── Sections ─────────────────────────────────────────────────────────────────
SPACESHIP_USER_SHOW=needed             # only when it is not you, or over ssh
SPACESHIP_USER_PREFIX=""
SPACESHIP_USER_SUFFIX=""
SPACESHIP_USER_COLOR="$sw_lilac"
SPACESHIP_USER_COLOR_ROOT="$sw_coral"

SPACESHIP_HOST_SHOW=needed             # only over ssh
SPACESHIP_HOST_PREFIX="@"
SPACESHIP_HOST_COLOR="$sw_neon"
SPACESHIP_HOST_COLOR_SSH="$sw_coral"   # a remote box should not look like home

SPACESHIP_DIR_PREFIX=""
SPACESHIP_DIR_COLOR="$sw_cyan"
SPACESHIP_DIR_TRUNC=3
SPACESHIP_DIR_TRUNC_PREFIX="…/"
SPACESHIP_DIR_TRUNC_REPO=true          # inside a repo, show it from its root
SPACESHIP_DIR_LOCK_SYMBOL=" "
SPACESHIP_DIR_LOCK_COLOR="$sw_coral"

SPACESHIP_GIT_PREFIX=""
SPACESHIP_GIT_SYMBOL=" "
SPACESHIP_GIT_BRANCH_COLOR="$sw_gold"
SPACESHIP_GIT_STATUS_PREFIX=" "
SPACESHIP_GIT_STATUS_SUFFIX=""
SPACESHIP_GIT_STATUS_COLOR="$sw_coral"
SPACESHIP_GIT_STATUS_UNTRACKED="?"
SPACESHIP_GIT_STATUS_ADDED="+"
SPACESHIP_GIT_STATUS_MODIFIED="✱"
SPACESHIP_GIT_STATUS_RENAMED="»"
SPACESHIP_GIT_STATUS_DELETED="✘"
SPACESHIP_GIT_STATUS_STASHED="≡"
SPACESHIP_GIT_STATUS_UNMERGED="⚡"
SPACESHIP_GIT_STATUS_AHEAD="⇡"
SPACESHIP_GIT_STATUS_BEHIND="⇣"
SPACESHIP_GIT_STATUS_DIVERGED="⇕"

SPACESHIP_PACKAGE_PREFIX=""              # its own default is "is ", the one
SPACESHIP_PACKAGE_SYMBOL="□ "            # section that ignores DEFAULT_PREFIX
SPACESHIP_PACKAGE_COLOR="$sw_lilac"

SPACESHIP_NODE_SYMBOL="⬢ "
SPACESHIP_NODE_COLOR="$sw_lime"
SPACESHIP_BUN_SYMBOL="◗ "
SPACESHIP_BUN_COLOR="$sw_lime"
SPACESHIP_DART_SYMBOL="◆ "
SPACESHIP_DART_COLOR="$sw_azure"
SPACESHIP_PYTHON_SYMBOL="◉ "
SPACESHIP_PYTHON_COLOR="$sw_gold"
SPACESHIP_RUBY_SYMBOL="◈ "
SPACESHIP_RUBY_COLOR="$sw_coral"
SPACESHIP_GOLANG_SYMBOL="◇ "
SPACESHIP_GOLANG_COLOR="$sw_cyan"
SPACESHIP_RUST_SYMBOL="⬡ "
SPACESHIP_RUST_COLOR="$sw_orange"
SPACESHIP_JAVA_SYMBOL="☕ "
SPACESHIP_JAVA_COLOR="$sw_neon"
SPACESHIP_VENV_SYMBOL="◉ "
SPACESHIP_VENV_COLOR="$sw_gold"

SPACESHIP_JOBS_SYMBOL="◍"
SPACESHIP_JOBS_COLOR="$sw_gold"

SPACESHIP_EXIT_CODE_SHOW=true          # off by default, and worth knowing
SPACESHIP_EXIT_CODE_PREFIX=""
SPACESHIP_EXIT_CODE_SYMBOL="✘ "
SPACESHIP_EXIT_CODE_COLOR="$sw_coral"

# ── The caret ────────────────────────────────────────────────────────────────
SPACESHIP_CHAR_PREFIX="%F{$sw_neon}╰─%f"
SPACESHIP_CHAR_SYMBOL="▸ "
SPACESHIP_CHAR_SYMBOL_SECONDARY="▹ "   # PS2, when a quote is still open
SPACESHIP_CHAR_COLOR_SUCCESS="$sw_neon"
SPACESHIP_CHAR_COLOR_FAILURE="$sw_coral"
SPACESHIP_CHAR_COLOR_SECONDARY="$sw_gold"

# ── The right side ───────────────────────────────────────────────────────────
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_PREFIX=""
SPACESHIP_EXEC_TIME_SUFFIX=""
SPACESHIP_EXEC_TIME_ELAPSED=3          # only once a command was worth timing
SPACESHIP_EXEC_TIME_COLOR="$sw_dim"

SPACESHIP_TIME_SHOW=true
SPACESHIP_TIME_PREFIX=" · "            # dropped when exec_time is not there
SPACESHIP_TIME_SUFFIX=""
SPACESHIP_TIME_FORMAT="%D{%H:%M}"
SPACESHIP_TIME_COLOR="$sw_dim"

unset sw_neon sw_cyan sw_gold sw_coral sw_lime sw_orange sw_azure sw_lilac sw_dim
