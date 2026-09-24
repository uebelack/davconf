# Synthwave '85 for everything the prompt does not cover: the line you are
# typing, the suggestion in front of the caret, the completion menu and ls.
#
# Sourced from zshrc *after* oh-my-zsh, because zsh-syntax-highlighting and the
# completion zstyles come with the plugins and would otherwise overwrite this.
#
# Same hexes as ghostty/config, one job each:
#   #00f0ff cyan    a command that exists        #fe4450 coral   one that does not
#   #fede5d gold    quoted text                  #f92aad magenta operators, flags
#   #72f1b8 lime    keywords, sudo               #d4c8ff lilac   paths
#   #495495 dim     comments, the suggestion

# ── The line you are typing ──────────────────────────────────────────────────
# zsh-syntax-highlighting colours the command line as you type it: the single
# most useful bit is that a command turns cyan only once zsh can actually find
# it, so a typo stays coral and you see it before pressing enter.
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#fe4450,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#72f1b8'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#72f1b8,italic'
ZSH_HIGHLIGHT_STYLES[command]='fg=#00f0ff'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#00f0ff'
ZSH_HIGHLIGHT_STYLES[function]='fg=#00f0ff'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#8bfff5'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#8bfff5'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#8bfff5'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#00f0ff'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#d4c8ff,underline'
ZSH_HIGHLIGHT_STYLES[path]='fg=#d4c8ff'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#495495'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#d4c8ff,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ff8b39'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#ff8b39'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#f92aad'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#f92aad'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#fb66c4'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#fede5d'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#fede5d'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#fede5d'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#fb66c4'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#fb66c4'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#d4c8ff'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#f92aad,bold'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#f92aad,bold'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#f92aad'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#495495,italic'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#fede5d'

# Nested brackets, so a long pipeline shows you where it closes — and an
# unclosed one turns coral.
ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=#fe4450,bold'
ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=#f92aad'
ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=#00f0ff'
ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=#fede5d'
ZSH_HIGHLIGHT_STYLES[bracket-level-4]='fg=#72f1b8'
ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]='standout'

# ── The suggestion in front of the caret ─────────────────────────────────────
# Dim enough to read past, bright enough to notice. The plugin reads this when
# it draws, so setting it after the plugin loaded is fine.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#495495'

# ── ls ───────────────────────────────────────────────────────────────────────
# LS_COLORS is the full-colour one, read by the completion menu below (and by
# GNU ls, if a machine has coreutils). macOS ships BSD ls, which only knows
# LSCOLORS and its eight colours — so both are set, and the palette degrades
# rather than disappears.
export CLICOLOR=1
export LS_COLORS='di=38;2;0;240;255:ln=38;2;254;222;93:mh=00:pi=38;2;255;139;57:so=38;2;255;126;219:do=38;2;255;126;219:bd=38;2;73;84;149:cd=38;2;73;84;149:or=38;2;254;68;80,underline:mi=38;2;254;68;80:su=38;2;26;16;51,48;2;254;68;80:sg=38;2;26;16;51,48;2;255;139;57:ca=00:tw=38;2;26;16;51,48;2;0;240;255:ow=38;2;0;240;255,underline:st=38;2;212;200;255,48;2;36;27;58:ex=38;2;255;126;219:*.tar=38;2;255;139;57:*.tgz=38;2;255;139;57:*.zip=38;2;255;139;57:*.gz=38;2;255;139;57:*.bz2=38;2;255;139;57:*.xz=38;2;255;139;57:*.7z=38;2;255;139;57:*.dmg=38;2;255;139;57:*.jpg=38;2;255;184;243:*.jpeg=38;2;255;184;243:*.png=38;2;255;184;243:*.gif=38;2;255;184;243:*.svg=38;2;255;184;243:*.webp=38;2;255;184;243:*.mp4=38;2;255;184;243:*.mov=38;2;255;184;243:*.mp3=38;2;255;184;243:*.pdf=38;2;254;68;80:*.md=38;2;212;200;255:*.json=38;2;254;222;93:*.yml=38;2;254;222;93:*.yaml=38;2;254;222;93:*.toml=38;2;254;222;93:*.sh=38;2;114;241;184:*.zsh=38;2;114;241;184:*.py=38;2;114;241;184:*.ts=38;2;114;241;184:*.js=38;2;114;241;184:*.rs=38;2;114;241;184:*.go=38;2;114;241;184'
# dir cyan, symlink gold, socket/pipe magenta, executable magenta.
export LSCOLORS='gxdxfxdxfxexexabagacad'

# ── The completion menu ──────────────────────────────────────────────────────
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
# ma= is the highlight on the entry you are moving over: indigo text on neon.
# One call, both values — a second zstyle for the same style would replace this
# one rather than add to it.
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" "ma=38;2;26;16;51;48;2;249;42;173"
zstyle ':completion:*:descriptions' format '%F{#f92aad}── %d%f'
zstyle ':completion:*:corrections'  format '%F{#fede5d}── %d (errors: %e)%f'
zstyle ':completion:*:messages'     format '%F{#00f0ff}── %d%f'
zstyle ':completion:*:warnings'     format '%F{#fe4450}── no matches%f'
# Processes, for kill<TAB> — the pid coral, so it is the thing you read.
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=38;2;254;68;80'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
