# davconf

My machine configuration, in modules. Run `./update.sh` to set a machine up,
and again whenever you want it back in sync with this repo.

## Setup, and keeping machines in sync

```sh
git clone git@github.com:uebelack/davconf.git ~/davconf
cd ~/davconf
./update.sh              # core setup
./brew/update.sh --list  # then pick this machine's package profiles
```

Then fill in `~/.zshrc.local` and open a new shell.

`update.sh` is the same command for setting a machine up and for keeping it
current — it is idempotent, so run it again any time. It fast-forwards this
repo first, so config committed on another machine lands here. Each module has
its own `update.sh` if you only want that part.

## Daily auto-update

The first interactive shell of the day runs `update.sh` in the background, so
every machine drifts back into sync on its own. Shell startup is not blocked:
the run is detached and survives closing the terminal, and a note points at the
log. If the run fails, the next shell says so, once.

Only one run happens per day no matter how many terminals you open — the first
one takes an atomic lock. Tune it in `~/.zshrc.local`:

```sh
DAVCONF_AUTO_UPDATE=0                  # switch it off
DAVCONF_UPDATE_INTERVAL=86400          # seconds between runs
DAVCONF_UPDATE_PROFILES="dev cloud"    # override ~/.config/davconf/profiles
DAVCONF_UPDATE_UPGRADE=0               # install missing, but upgrade nothing
```

State lives in `~/.local/state/davconf`: `last-update` (timestamp of the last
attempt), `update.log` (output of the most recent run) and `failed` (present
when that run exited non-zero).

To force a run now: `rm ~/.local/state/davconf/last-update` and open a shell,
or just run `./update.sh`.

The background run has no terminal, so anything needing a password fails rather
than hanging — a cask that wants `sudo` will show up in the log as an error.
Run `./update.sh` by hand to deal with those.

The pull runs on every invocation — config committed on another machine reaches
this one no other way, so a quietly skipped pull is how a machine goes stale
without anyone noticing. It is `--ff-only`, which is what makes running it
unconditionally safe: git refuses rather than rewriting history or overwriting
a modified file, so local work is never touched. A dirty working tree is
therefore no reason to skip it; git fast-forwards the files it can and aborts
by itself if a local edit is in the way.

When the pull cannot happen — offline, diverged history, a local edit blocking
an incoming change — the run continues with the checked-out version and says so
with git's own message, so it shows up in `update.log` instead of looking like
a clean run. `./update.sh --no-pull` is the deliberate opt-out.

If the pull brought in a new `update.sh`, the script re-executes itself so the
rest of the run uses the version that was just fetched, not the one bash
started reading. Nothing has run at that point, so no work is repeated.

One manual step on a brand-new machine: Homebrew keeps third-party tap trust in
`~/.homebrew/trust.json`, which no Brewfile can set, so `Brewfile.privat` needs

```sh
brew trust --tap arthur-ficial/tap
```

## Modules

| Module      | What it does                                             |
| ----------- | -------------------------------------------------------- |
| `update.sh` | Pulls this repo, then runs every module below, in order    |
| `brew/`     | Homebrew itself, plus per-machine package profiles         |
| `jenv/`     | Registers every installed JDK with jenv                    |
| `zsh/`      | oh-my-zsh, spaceship prompt, plugins, `.zshrc` + `.zprofile` |
| `ghostty/`  | The Ghostty terminal config, linked into `~/.config`      |
| `nvim/`     | The Neovim config — lazy.nvim and its plugins, linked into `~/.config` |
| `karabiner/`| Makes caps lock AeroSpace's leader, which AeroSpace cannot  |
| `aerospace/`| The AeroSpace window manager config, linked into `$HOME`    |
| `chrome/`   | The Synthwave '85 Chrome theme, and how to load it          |
| `vscode/`   | The Synthwave '85 theme for VS Code and Cursor              |
| `intellij/` | The Synthwave '85 theme for the JetBrains IDEs              |
| `mac/`      | macOS system defaults — the settings a fresh Mac gets wrong |

Every module runs even when an earlier one fails: a third-party tap breaking
upstream should not stop the shell, terminal, browser and macOS settings from
being updated. The failures are named at the end and the run still exits
non-zero, so nothing is swallowed.

### brew

`brew/update.sh` installs Homebrew first if the machine does not have it.
Packages live in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
split into profiles so each machine installs only what it is actually for:

| Profile   | Contents                                                   |
| --------- | ---------------------------------------------------------- |
| `common`  | Always applied: the bare terminal — vim, Neovim (+ ripgrep, fd), lazygit, gnupg, Ghostty, the Nerd Font |
| `dev`     | Toolchains: the version managers, Python, JVM              |
| `cloud`   | AWS, Azure, gcloud, Terraform                              |
| `privat`  | Machines with no install restrictions: GUI apps, general CLI tools, local AI, Spotify |

**Which profiles a machine gets is machine-local and not committed.** It lives
in `~/.config/davconf/profiles`, one name per line — so the same repo sets up a
work laptop and a personal one differently:

```sh
# ~/.config/davconf/profiles
dev
cloud
privat
```

`brew/update.sh` writes that file the first time it runs, with every profile
commented out, so there is something to edit rather than a blank page.
`common` is always applied and does not belong in it.

`privat` is not only about Spotify and WhatsApp: work machines are not allowed
to install things like `gh`, `docker` or Cursor, so anything that cannot go on
a restricted machine lives there. Keep `common` to what is installable
everywhere — do not "tidy" those entries back into it.

```sh
./brew/update.sh                 # common + this machine's profiles
./brew/update.sh dev cloud       # common + the named profiles (ignores the file)
./brew/update.sh --all           # common + every profile
./brew/update.sh --list          # which profiles exist, which are selected
./brew/update.sh --check         # what is missing? install nothing
```

Missing packages get installed; existing ones stay at their current version
unless you pass `--upgrade`, which also runs a full `brew upgrade` of every
outdated formula — `brew bundle --upgrade` alone would only touch packages
named in a Brewfile and leave their dependencies behind, which is most of what
`brew outdated` reports. Casks are left alone: upgrading them can need a
password, and the daily update runs with no terminal to type one into.

A first run on a fresh machine can ask for your password once: a few casks
need root to install — `docker-desktop` symlinks `kubectl` into a directory
that is not user-writable — and Homebrew escalates for that step. This is
Homebrew's doing, not the scripts'.

That step cannot work from the daily background run, which has no terminal to
type a password into. It fails only that profile and the rest of the run
continues, but such a cask stays uninstalled until `./update.sh` is run by hand
once. Worth doing as the first thing on a new machine.

The daily auto-update passes `--upgrade`, so the machine keeps itself current
on its own. Set `DAVCONF_UPDATE_UPGRADE=0` in `~/.zshrc.local` to install
missing packages but upgrade nothing.

To add a package, edit the right Brewfile — or dump the current machine's state
with `brew bundle dump --file=-` and cherry-pick. Note that `dump` omits
formulae installed from custom taps, so check its output before trusting it.

#### Machines that do not own /Applications

A managed Mac — a work machine under MDM — will not let you write to
`/Applications`, and every cask install fails on the copy at the very end.
Homebrew appends `HOMEBREW_CASK_OPTS` to every cask command, so pointing it at
`~/Applications` is the whole fix: macOS treats that as a real application
directory, Spotlight indexes it and Launchpad lists it.

`brew/update.sh` and `zsh/zprofile` both set it when, and only when,
`/Applications` is not writable — the test is the entire condition, so there is
no per-machine flag to remember and nothing changes on a machine that does own
`/Applications`. The two copies exist because the daily background update never
reads a login shell, and a `brew install --cask` typed by hand never runs
`brew/update.sh`. An existing `HOMEBREW_CASK_OPTS` is always left alone.

If the test gets it wrong — some machines pass it and still refuse the install —
state the answer instead: put a path in `~/.config/davconf/cask-appdir` and it
overrides the test outright.

```sh
echo '~/Applications' > ~/.config/davconf/cask-appdir
```

Fonts need nothing: casks put them in `~/Library/Fonts` already.

Where a cask actually put an app is not a guess: Homebrew moves the bundle to
the appdir and leaves a symlink behind in the Caskroom pointing at it.

```sh
readlink "$(brew --prefix)"/Caskroom/aerospace/*/*/AeroSpace.app
```

An app that landed in the wrong place moves with a reinstall, which is cheap —
the download is already cached:

```sh
brew uninstall --cask aerospace
brew install --cask aerospace          # with the appdir now in effect
```

What this does *not* rescue is a cask that ships a `.pkg` installer rather than
an app bundle — `temurin`, for one. Those run Apple's installer against `/` and
ask for an admin password no matter where `--appdir` points, so on a locked-down
machine they have to come from somewhere else.

### jenv

Homebrew installs JDKs and tells jenv about none of them, in two different
shapes: casks land in `/Library/Java/JavaVirtualMachines`, formulae in
`$(brew --prefix)/opt/openjdk*/libexec` where even `java_home -V` cannot see
them. `jenv/update.sh` finds both and registers whatever is missing.

```sh
./jenv/update.sh           # add any JDK jenv does not know yet
./jenv/update.sh --check   # list what would be added, add nothing
```

It runs straight after `brew/update.sh`, so a JDK a Brewfile just installed is
selectable in the same run. Already-registered JDKs are left alone, so it is
safe to run repeatedly.

Formula JDKs are registered by their stable `opt/` path rather than the Cellar
directory it resolves to — the Cellar path has the version number in it and
disappears on the next upgrade, which would leave jenv pointing at nothing.

### zsh

`zsh/update.sh` installs, and on later runs updates:

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)
- [spaceship-prompt](https://github.com/spaceship-prompt/spaceship-prompt) theme
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- symlinks `~/.zshrc` -> `zsh/zshrc` (any existing file is backed up first)
- appends a marked block to `~/.zprofile` that sources `zsh/zprofile`
- `zsh/autoupdate.zsh`, the daily background refresh described above

`~/.zprofile` is the one file this repo does not own outright. A managed machine
can have something of its own that rewrites it, and a symlink loses that fight
twice over: the davconf version is replaced, and a tool writing *through* the
symlink truncates `zsh/zprofile` in the checkout — which is how corporate `$PATH`
setup ends up in a git diff. So `zsh/update.sh` appends a marked block instead:

```sh
# >>> davconf >>>
[ -f ~/davconf/zsh/zprofile ] && . ~/davconf/zsh/zprofile
# <<< davconf <<<
```

Everything else in the file is left exactly as found. A rewrite that drops the
block costs nothing beyond the next update run, which puts it back — it
self-heals rather than fighting. The block sources the repo copy rather than
inlining it, so editing `zsh/zprofile` still takes effect without re-running the
script, and an older davconf's symlink is replaced with a real file on the first
run. `~/.zshrc` stays a symlink: nothing has ever fought us for it.

`zshrc` and `zprofile` split by *which shells read them*, not by topic. zsh
reads `~/.zprofile` for every login shell, interactive or not, and `~/.zshrc`
only for interactive ones — so a `$PATH` a script or a GUI-launched process
also needs goes in `zprofile`, and aliases, the prompt and completions go in
`zshrc`. pyenv is the reason the split matters: with its shims set up only in
`zshrc`, `python` silently falls back to the system one everywhere else, and
oh-my-zsh's pyenv plugin greets every new terminal with "Found pyenv, but it is
badly configured". `zprofile` also loads `brew shellenv`, since macOS leaves
`/opt/homebrew/bin` off the default `$PATH` and `zshrc` has not run yet.

#### The prompt

`zsh/prompt.zsh` configures spaceship in the Synthwave '85 palette — the same
hexes as `ghostty/config` and the greeting sun, so the terminal, the prompt and
the browser are one palette rather than three that rhyme.

```
╭─ …/davconf   main ✱+?  ⬢ 24.14.1              2.4s · 14:32
╰─▸ git push
```

Two lines on purpose: a deep path and a busy git status stay off the line you
type on, so the command always starts in the same column. The magenta frame and
caret are structural, the path is cyan, the branch gold, anything wrong coral —
including the caret itself, which turns coral when the last command failed. The
right side is what you only want after the fact: how long the command took (over
three seconds) and when it finished. Inside a repo the path is shown from the
repo root, so `…/davconf` is the root of this one and `…/davconf/zsh` a
directory in it.

What it shows is git and language versions, and nothing else: the branch and
working-tree state, and the runtime version of whatever the directory is a
project of — `⬢` node, `◈` ruby, `◉` python, `☕` java, `◆` dart, `⬡` rust,
`◇` go, `□` the package version itself. The cloud and container sections
spaceship offers (aws, gcloud, kubectl, terraform, docker context) are
deliberately left out: what they report is rarely what the next command depends
on. Adding one back is a line in `SPACESHIP_PROMPT_ORDER` plus its colour
underneath.

It is sourced *before* oh-my-zsh, which matters: every spaceship section takes
its defaults the moment the theme loads, and only for settings that are not
already set.

`zsh/colors.zsh` does the same for everything the prompt does not cover — the
line as you type it (a command turns cyan only once zsh can actually find it,
so a typo stays coral), the autosuggestion, the completion menu and `ls`. It is
sourced *after* oh-my-zsh, since the plugins it loads set those same variables.

#### Weather behind a proxy

The weather line is the only part of the greeting that leaves the machine, so
it is the only part a corporate proxy breaks. It is fetched over https with the
proxy taken from the environment — `https_proxy`, `HTTPS_PROXY`, `all_proxy`,
`ALL_PROXY`, and the `http_proxy` pair as a last resort — and `no_proxy` passed
through as `--noproxy`, so an exclusion list still excludes.

Resolving it in the script rather than leaving it to curl is deliberate. curl
honours `https_proxy`, `HTTPS_PROXY` and lowercase `http_proxy`, but
deliberately ignores an uppercase `HTTP_PROXY`, since a CGI script would inherit
one straight from a request header. A machine exporting only the uppercase pair
would fetch direct — and on a network that requires the proxy, that is eight
seconds of nothing in every new terminal until the timeout gives up.

Nothing blocks on it either way: the greeting prints the cached value and
refreshes in the background, so a failed fetch costs you a slightly stale line,
not a slow prompt.

#### Startup time

Shells open in about 0.6s. They used to take 1.3s, and all of the difference
was nvm: the oh-my-zsh `nvm` plugin sources `nvm.sh` on every start, which takes
half a second to do one thing that matters — put the default node version on
`$PATH`. `zshrc` now does that part itself by reading `~/.nvm/alias/default` and
globbing for the matching version directory, no forks, about a millisecond;
`nvm` itself is a stub function that loads the real thing on first use and
re-runs your command. `node`, `npm` and globally installed packages are on
`$PATH` from the start exactly as before.

Worth knowing when this gets slow again: `zsh/update.sh` does not profile
anything for you, but

```sh
ZDOTDIR=$(mktemp -d) sh -c 'printf "zmodload zsh/zprof\nsource ~/.zshrc\nzprof | head -20\n" > $ZDOTDIR/.zshrc; zsh -i -c exit'
```

names the expensive function outright. Ignore `compinit` and `compdump` in that
output — the throwaway `ZDOTDIR` sends oh-my-zsh's completion dump somewhere
new, so it rebuilds it every time you profile and never in a real shell.

### ghostty

`ghostty/update.sh` links `~/.config/ghostty/config` to `ghostty/config` in this
repo — the theme, font, padding, keybindings and scrollback settings for the
[Ghostty](https://ghostty.org) terminal. An existing real file is backed up
first, and a link that already points here is left alone.

```sh
./ghostty/update.sh          # link the config
./ghostty/update.sh --check  # report what would change, change nothing
```

Because it is a symlink, editing `ghostty/config` is enough: reload a running
Ghostty with `cmd+shift+r` and the change applies without another run.

`~/.config/ghostty/config` is the path this repo owns. Ghostty also reads
`~/Library/Application Support/com.mitchellh.ghostty/config` on macOS and merges
both, so leave that one absent — settings split across the two are the kind of
thing that takes an afternoon to debug. Check what Ghostty actually ended up
with using `ghostty +show-config`.

### nvim

`nvim/update.sh` links `~/.config/nvim` to `nvim/config` in this repo, then
installs any plugin that is missing. An existing real directory is backed up
first, and a link that already points here is left alone.

```sh
./nvim/update.sh          # link the config, install missing plugins
./nvim/update.sh --check  # report what would change, change nothing
```

Unlike `ghostty/` and `aerospace/`, this links the whole directory rather than
a single file. A Neovim config is a tree — `init.lua` plus everything under
`lua/` — so linking entry by entry would mean editing the script every time a
file is added.

Plugins are managed by [lazy.nvim](https://lazy.folke.io), which is not a
Homebrew entry: `nvim/config/init.lua` clones it on first start into
`~/.local/share/nvim/lazy`, which is also where every plugin ends up. Nothing a
plugin manager owns lands in this repo except `nvim/config/lazy-lock.json`.

**That lockfile is the point of committing this at all.** It pins the exact
commit of every plugin, so a new machine gets the same versions as the one it
was set up from, instead of whatever happened to be `HEAD` that day. It is
written into the repo through the symlink, so:

```sh
nvim +Lazy      # press U to update, or :Lazy update
                # then commit nvim/config/lazy-lock.json
```

`update.sh` runs `Lazy! install`, never `Lazy! update` — it only clones what is
absent, at the locked commit. The daily unattended run must not be able to move
plugins underneath a machine that was working yesterday; updating is something
you do on purpose, and the commit is what carries it to the other machines.

Adding a plugin is adding a file under `nvim/config/lua/plugins/` that returns
a spec. Nothing else needs touching — `init.lua` imports the whole directory.
An nvim that was already open when the plugin was added has registered the
command stubs but has nothing to load behind them, and says `Plugin … is not
installed` — restart it, or run `:Lazy install` in that session.

luarocks is switched off (`rocks = { enabled = false }`). lazy.nvim's default
is to build a private Lua 5.1 and luarocks under `~/.local/share/nvim/lazy-rocks`
so a plugin that needs a rock can have one, and `:checkhealth lazy` reports an
error until that build succeeds. Nothing here needs it. Turn it back on if a
plugin added under `lua/plugins/` ever declares a rock dependency.

#### The colour scheme

`nvim/config/colors/synthwave-85.lua` is the same Synthwave '85 palette as
`ghostty/config`, the prompt, the Chrome theme and the two editor themes —
same eight backgrounds, same sixteen neons, same roles:

| Colour    |           | Role                                          |
| --------- | --------- | --------------------------------------------- |
| cyan      | `#00f0ff` | what you call — functions, methods, links      |
| gold      | `#fede5d` | text you wrote — strings, attribute values     |
| magenta   | `#f92aad` | structure and control flow — keywords, storage |
| coral     | `#fe4450` | punctuation and operators; separately, errors  |
| green     | `#72f1b8` | types and classes                              |
| orange    | `#ff8b39` | literals — numbers, constants, escapes, regex  |
| lavender  | `#d4c8ff` | variables                                      |
| dim       | `#495495` | what you can skim past — comments, line numbers |

It is a file in `colors/`, not a plugin: nothing to clone, so it cannot be the
thing that is missing on a machine that has not reached the network yet.
`init.lua` sets `termguicolors` before loading it — without that, nvim renders
the scheme against the terminal's own sixteen colours and the result is a
muddier, differently wrong palette rather than an obvious failure.

**Keep it in step with the other themes.** Magenta and coral were swapped once
already (keywords used to be coral, punctuation magenta). If this file ever
disagrees with `vscode/theme` or `intellij/theme` about which is which, they
are the ones that moved and this is the one to fix.

The VS Code theme writes its washes as eight-digit hex — `#f92aad33` is magenta
at 20% over whatever is behind it. Neovim highlights have no alpha channel, so
the file mixes those down with a small `blend()` helper rather than pasting the
results: the intent stays readable as "magenta at 20%" instead of `#482655`.

Covered: editor chrome, the legacy vim syntax groups, the full treesitter
`@`-captures, LSP semantic tokens (which win over treesitter where a server
provides them, so they are kept in agreement), diagnostics, diff, Telescope's
three panes, lazy.nvim's window, and `:terminal` — given the Ghostty palette
verbatim, so a shell inside nvim inside Ghostty is the same sixteen colours the
whole way down.

#### Telescope

The one plugin configured so far, under `<leader>f` with space as the leader:

| Key          | Picker                    |
| ------------ | ------------------------- |
| `<leader>ff` | Find files                |
| `<leader>fg` | Live grep                 |
| `<leader>fb` | Open buffers              |
| `<leader>fh` | Help tags                 |

`ripgrep` and `fd` are in `Brewfile.common` for this and are not optional
extras. Telescope shells out to them; without them it falls back to `grep` and
`find` and feels broken on any repo big enough to want a fuzzy finder for.
`find_files` is set to show dotfiles — in a config repo, hiding them hides most
of what you are looking for — with `.git/` still excluded.

#### Neo-tree

The project sidebar — `<leader>e` toggles it. This is deliberately not the
same job as Telescope: Telescope answers "where is the file I am already
thinking of", neo-tree answers "what is in here". Reaching for the wrong one
of those is what makes people believe they do not need a file explorer, or do
not need a fuzzy finder.

| Key           | Opens                        |
| ------------- | ---------------------------- |
| `<leader>e`   | Toggle the tree              |
| `<leader>E`   | Reveal the current file in it |
| `<leader>ge`  | Changed files (git status)   |
| `<leader>be`  | Open buffers                 |

Inside the tree, `l` opens and `h` closes a node, `s` and `v` open in a split.
It follows the current file, so the sidebar is never showing a part of the
project you left ten minutes ago. Dotfiles are shown for the same reason
Telescope's `find_files` shows them — in a config repo, hiding them hides most
of the repo — while `.git`, `.DS_Store` and `node_modules` stay hidden, since
that is noise rather than config.

netrw is switched off so it cannot open its own directory listing over the
top. That has one consequence worth knowing: `nvim .` creates a directory
buffer *before* anything has pressed `<leader>e`, so with nothing loaded to
hijack it the result would be an empty buffer and no explorer. The plugin's
`init` loads neo-tree early in exactly that case — nvim started on a
directory — and leaves every other start lazy.

Icons come from the Nerd Font in `Brewfile.common`. Ghostty is set to
JetBrains Mono and falls back to it for glyphs it does not have, so the
terminal font does not need changing.

#### Copilot

`copilot.lua` rather than the official `github/copilot.vim`: virtual text is
what is wanted here, and copilot.lua is the one that does it standalone rather
than as a source inside a completion engine. Suggestions appear inline, dimmed
and italic, as you type.

| Key        | Does                        |
| ---------- | --------------------------- |
| `<C-y>`    | Accept the suggestion       |
| `<C-l>`    | Accept one more word of it  |
| `<C-Down>` | Next suggestion             |
| `<C-Up>`   | Previous suggestion         |
| `<C-e>`    | Dismiss                     |

**These are not the upstream defaults, and the reasons are worth keeping.**
Upstream binds alt — `<M-l>`, `<M-]>`, `<M-[>`. On the Swiss German layout this
repo is built for, plain alt is where `[ ] | { } # @ ~` live (the same fact that
makes `karabiner/` necessary), so an alt keymap here either types a bracket or
eats one.

The second reason is subtler. copilot.lua binds `accept`, `accept_word` and
`dismiss` *with passthrough* — with no suggestion on screen the key still does
what it always did, so `<C-y>` and `<C-e>` keep inserting the character above
and below. It binds `next` and `prev` **without** passthrough: whatever those
are given stops doing its old job entirely. That rules out `<C-k>`, which is
digraph entry, and `<C-j>`, which is a newline. Control plus an arrow has no
insert-mode meaning to lose.

There is a completion engine now — see [Completion](#completion) — and the two
share the same line of screen without colliding. blink's own ghost text is off,
because it draws where the Copilot suggestion already is, and blink's keymap
avoids `<C-y>` and `<C-e>` so the table above keeps working. The split ends up
readable: **`<C-y>` takes what Copilot wrote, `<CR>` takes what the language
server suggested.**

No Node needed. Current copilot.lua downloads a native `copilot-language-server`
binary into `~/.local/share/nvim/copilot.lua/` on first load — which matters
here, because Node comes from `nvm` in the `dev` profile and a machine without
that profile has none.

Authentication is shared, not per-editor: the token lives in
`~/.config/github-copilot/`, so a machine where the JetBrains IDEs are already
signed in needs nothing. On a fresh one, `:Copilot auth` once. `:Copilot status`
says whether it is online and attached.

#### Language servers

Java, TypeScript, JavaScript and Angular, plus the filetypes an Angular
component is actually made of. `nvim/config/lua/plugins/lsp.lua` has all three
plugins in one file because they are one feature and none of them does anything
alone:

| Plugin                 | Job                                                     |
| ---------------------- | ------------------------------------------------------- |
| `mason.nvim`           | Installs the server binaries                             |
| `mason-lspconfig.nvim` | Installs the ones named in `ensure_installed`, then enables every server mason has |
| `nvim-lspconfig`       | A directory of `lsp/<server>.lua` files: where each binary is, and what a project root looks like for it |

| Server      | Covers                                                |
| ----------- | ----------------------------------------------------- |
| `jdtls`     | Java                                                  |
| `ts_ls`     | JavaScript and TypeScript                             |
| `angularls` | Angular templates, and the template side of a component class |
| `eslint`    | The lint rules a project configures, as diagnostics   |
| `html`      | Templates that are not Angular                        |
| `cssls`     | Component styles                                      |
| `jsonls`    | `angular.json`, `tsconfig.json`, `package.json` — with schemas |

**Almost none of this is a plugin API any more.** Since Neovim 0.11 the
launching, merging and enabling is built in — `vim.lsp.config()` and
`vim.lsp.enable()` — and nvim-lspconfig is reduced to data on the runtimepath.
That is why the per-server settings in this repo are not in `lua/plugins/` but
in `nvim/config/after/lsp/<server>.lua`: `after/` is the standard Vim mechanism
for overriding a runtime file a plugin provided, Neovim merges the two with
this side winning, and the file is only read when a buffer of that language
opens. Putting them in the plugin spec would mean building every server's
settings table on every start. See `:help lsp-config-merge`.

**Why mason and not Homebrew,** which is this repo's package manager for
everything else: Angular's server is not in homebrew at all, and
`typescript-language-server` would pull brew's own node in alongside the `nvm`
one that `zsh/zshrc` puts on `$PATH`. mason installs all of them under
`~/.local/share/nvim/mason` using the node already there — the same bargain
lazy.nvim makes one level up. What it costs is `lazy-lock.json`'s guarantee:
plugin commits are pinned and committed, server versions are whatever mason
fetched. `:Mason` lists them, `u` updates one, `U` updates all.

**The servers install on the first interactive `nvim`, not from `update.sh`.**
mason-lspconfig skips `ensure_installed` in headless mode by design, and
`nvim/update.sh` is headless — so a fresh machine gets the plugins from the
unattended run and the server binaries the first time a real editor opens.
That first start downloads a few hundred MB and shows progress while it does.
`:Mason` is where to watch it, and `:MasonInstall <package>` forces one by hand.

##### Keys

Most of what you want is already mapped by Neovim itself and is deliberately
not repeated in this config — `grn` rename, `gra` code action, `grr`
references, `gri` implementation, `grt` type definition, `gO` document symbols,
`K` hover, `<C-s>` signature help in insert mode, `[d` and `]d` to step through
diagnostics. See `:help lsp-defaults`. What the config adds is what Neovim
leaves out:

| Key          | Does                                        |
| ------------ | ------------------------------------------- |
| `gd`         | Go to definition                            |
| `gD`         | Go to declaration                           |
| `<leader>cd` | Diagnostics for this line, in a float       |
| `<leader>cf` | Format the buffer                           |
| `<leader>ci` | Toggle inlay hints                          |

`<leader>c` for code, since `<leader>f` is Telescope and `<leader>e` is the
explorer. Inlay hints are off until asked for: they are useful while reading
unfamiliar code and in the way while writing familiar code, and which of those
you are doing is not something a config file can know.

Diagnostics are configured because Neovim shows none of it by default —
`virtual_text` and `signs` are both off out of the box, so an unconfigured LSP
setup looks like it is doing nothing until you land on the line. Nothing in
`lsp.lua` picks a colour: `Diagnostic*`, `DiagnosticVirtualText*` and
`LspInlayHint` are all already in `colors/synthwave-85.lua`. Virtual text names
its server when more than one is attached, which in a TypeScript buffer is the
normal case — `ts_ls`, `angularls` and `eslint` all have opinions about the
same line, and without the attribution you cannot tell whose rule you are
looking at.

##### Java

`after/lsp/jdtls.lua` discovers every JDK under
`/Library/Java/JavaVirtualMachines` — the `temurin@17`, `@21` and `@25` casks
in `Brewfile.dev` all land there — reads the major version out of each one's
`release` file, and hands jdtls the list. A Maven project that declares
`maven.compiler.release` is then analysed against that JDK rather than against
whatever the server happens to be running on.

**The JDK that runs jdtls is a separate question from the JDKs it compiles
against, and `jenv` is what makes it one.** jdtls needs Java 21 or newer to
start at all, and `java` on `$PATH` is a jenv shim that resolves to whatever
`.java-version` the project pins — so opening a Java 17 project would hand
jdtls a 17 and it would refuse to launch, with a class-file-version stack trace
that reads like a problem with the project. The config pins the newest JDK ≥ 21
for the server process only, through `cmd_env`. Not by exporting `JAVA_HOME`:
that would be inherited by `:terminal` and by anything run from it, and Maven
prefers `JAVA_HOME` over `$PATH`, so a jenv-pinned project would quietly
compile against the wrong JDK.

This is plain jdtls through `vim.lsp`, not the `nvim-jdtls` plugin. What that
leaves out is the Eclipse-specific extensions — running a single test from the
buffer, the debugger, extract-to-method. Everything else is here. `nvim-jdtls`
is the upgrade path if the test running is ever missed.

jdtls keeps an index per project under `~/.cache/nvim/jdtls/workspace/`, keyed
only by the project directory's name, and it is not always self-healing. When
it starts insisting on a dependency that is no longer in the pom, deleting that
directory and reopening is the fix.

#### Completion

`blink.cmp`, in `nvim/config/lua/plugins/blink.lua` — the menu the language
servers above feed, with `friendly-snippets` behind the snippet source. Sources
are LSP, path, snippets and buffer, in that order; buffer is last because in a
Java or TypeScript file every word in it is also a word the server knows,
spelled better.

| Key          | Does                                              |
| ------------ | ------------------------------------------------- |
| `<C-n>`      | Open the menu / next item                         |
| `<C-p>`      | Previous item                                     |
| `<CR>`       | Accept                                            |
| `<Tab>`      | Next snippet placeholder                          |
| `<S-Tab>`    | Previous snippet placeholder                      |
| `<C-Space>`  | Show the menu, or toggle the documentation window |
| `<C-c>`      | Cancel                                            |

**None of blink's four presets are used, and that is the point.** All of them
bind `<C-e>` and `<C-y>` — both already Copilot's, for reasons the Copilot
section works through and that are not worth re-litigating for a menu — and all
of them bind `<C-k>`, which is digraph entry. So every key is spelled out with
`preset = "none"`, and each one ends in `fallback`: with no menu open `<CR>` is
still a newline, `<Tab>` still indents, `<C-n>` and `<C-p>` are still Vim's own
keyword completion.

`version = "1.*"` is not optional. The fuzzy matcher is Rust, and the release
tags are what carry prebuilt binaries for it; tracking the default branch would
find no binary and need `build = "cargo build --release"` and a Rust toolchain
this repo does not install. The default branch is also where blink's v2 is
being built, which additionally wants a separate `blink.lib` plugin.

It has no lazy trigger, unlike everything else here. `lsp.lua` asks blink for
the completion capabilities to advertise to servers — at `BufReadPre`, before
anything has entered insert mode — so an `event = "InsertEnter"` would be a lie
lazy.nvim quietly resolves by loading it anyway. It costs about 3ms of a 16ms
startup.

Nothing in the file picks a colour. blink's highlight groups link to `Pmenu`,
`PmenuSel`, `PmenuKind` and `PmenuMatch`, which `colors/synthwave-85.lua`
already defines, so the menu is in palette without being mentioned by it.

#### Treesitter

`nvim-treesitter` is what makes Telescope's preview pane show highlighted
source rather than plain text, and it replaces Vim's regex highlighting in the
buffer too. It is pinned to the `master` branch on purpose: the `main` branch
is an in-progress rewrite with a different API and no `ensure_installed`, so
an unpinned `:Lazy update` would move onto it and break the setup call.

Parsers are compiled C, built on the machine into the plugin's own directory
under `~/.local/share/nvim/lazy` — nothing lands in this repo, and they are not
in the lockfile because they follow whatever `nvim-treesitter` commit is. The
`ensure_installed` list covers what this repo is made of, what every repo has,
and the languages the servers above run for — a server and a parser answer
different questions about the same buffer, and the editor feels half-configured
with only one of them. `auto_install` picks up anything else the first time you
open one.

Both run in the background after the first start, so a fresh machine has a
short window where a file opens unhighlighted and then repaints. `:TSUpdate`
rebuilds them by hand, and `:checkhealth nvim-treesitter` lists what is
installed — note that it reports "no healthcheck found" until the plugin is
loaded, since it is lazy.

Building needs a C compiler. On macOS that is the Xcode command line tools,
which `git` has already pulled in on any machine this repo has run on.

Note that `$EDITOR` is still `vim`, set in `zsh/zshrc`. Neovim is the one you
open on purpose, not the one git drops you into.

### vscode

`vscode/theme` is a colour theme extension in the same Synthwave '85 palette as
`ghostty/config`, the prompt and the Chrome theme — indigo editor, magenta
structure, cyan for what you call, gold for text you wrote, coral for control
flow and anything wrong. The integrated terminal gets the Ghostty palette
verbatim, all sixteen ANSI colours, so the terminal inside the editor and the
terminal beside it are the same terminal.

```sh
./vscode/update.sh          # build and install where out of date
./vscode/update.sh --check  # report what would change, change nothing
```

A symlink into `~/.cursor/extensions` used to be the whole install, and that is
no longer true. Current VS Code and Cursor keep the list of installed
extensions in `extensions.json` beside them and scan *that*, not the directory:
a folder nobody registered is not a discovery, it is a leftover. The scan
writes its name into `.obsolete`, the delete-later list, and skips it from then
on. Nothing looks broken from outside — the link is healthy, the manifest is
valid, `--check` says "linked", and the theme is simply absent from the picker.
The only place that says so is the editor's own log, once per start:

```
[info] Marked extension as removed davconf.synthwave-85-1.0.0
```

So the theme goes in the way the editor expects, through its own CLI, which
means packaging it as a `.vsix` first — a zip holding the manifest, the
content-type map and the extension itself. `vsce` would build it, but it wants
node and the network for what is three files in an archive, so `zip` does it
instead. The vsix is a build artifact and is not committed. It is rebuilt and
reinstalled whenever a source file is newer than the installed copy, so a `git
pull` that changes the theme reaches the editor on the next run.

What that costs is liveness: the editor now owns a copy, so editing
`vscode/theme/themes/synthwave-85-color-theme.json` no longer arrives on
restart alone — it arrives on the next run of this script. The intellij module
makes the same trade for the same reason.

"Up to date" is read off `extensions.json`, not off the directory. An uninstall
leaves the folder behind to delete later, so a folder can outlive its
registration — and trusting it would mean reporting "up to date" about an
extension the editor has already written off, which is the exact failure this
module exists to avoid. The directory is asked one thing only: how old it is.

Two pieces of the old approach are cleaned up on the way past, since a machine
that ran the previous version has both: the symlink, which occupies the
directory name the install wants, and that name in `.obsolete`, which would
have the next scan skip the fresh copy just as it skipped the link. Only our
own key is removed; the rest of that list belongs to other extensions.

An editor counts as installed if *any* of its traces exist: the extensions
directory, its `settings.json`, its app bundle in `/Applications` or
`~/Applications`, or its CLI on `$PATH`. The extensions directory alone is not
proof — an editor that has never installed an extension does not have one yet,
and treating that as "not installed" silently skips a perfectly real editor.
The CLI is the piece that does the installing, so when it is not on `$PATH` it
is looked for at `Contents/Resources/app/bin/` inside the bundle, where every
one of them ships it; an editor with no CLI anywhere is reported rather than
skipped quietly.

`package.json` asks for `engines.vscode: ^1.40.0` deliberately. A colour theme
has no API surface to break against, and a higher floor only means an older
editor — a work machine on a managed release, say — refuses to load it.

Selecting it is a line in each editor's `settings.json`, a file this repo does
not own and will not rewrite — so the module reports which editors have it
selected and prints the one manual step for the rest: `cmd+shift+p` →
"Preferences: Color Theme" → Synthwave '85. `touch
~/.config/davconf/no-vscode-theme` on a machine that does not want it.

### intellij

`intellij/theme` is the same Synthwave '85 palette for the JetBrains IDEs — a UI
theme plus an editor colour scheme, and the Ghostty ANSI palette for the
built-in terminal and run console.

```sh
./intellij/update.sh          # build and install where out of date
./intellij/update.sh --check  # report what would change, change nothing
```

JetBrains IDEs will not read a loose theme file the way VS Code does: a UI theme
has to be a plugin. This is the smallest one that can exist — `plugin.xml`, the
theme JSON and the colour scheme XML, no code at all — so building it is zipping
three files into a jar. No Gradle, no JDK, nothing to install first.

The jar is a build artifact and is not committed. It is rebuilt whenever a
source file is newer than the installed copy, so a `git pull` that touches the
theme reinstalls it on the next run. IDEs are found by looking for an
`options/` directory under `~/Library/Application Support/JetBrains` and
`~/Library/Application Support/Google` — which is what separates a real IDE
config directory from Toolbox's own.

The editor colour scheme inherits from Darcula (`parent_scheme`), so a language
the scheme never heard of still looks right rather than falling back to the
light defaults.

Selecting it is one step per IDE, after a restart: Settings → Appearance &
Behavior → Appearance → Theme → Synthwave '85. The editor colours come with it.
The module reports which IDEs have it selected and will not write the setting
itself — the IDE rewrites `options/*.xml` when it exits and would drop anything
put there while it was running. `touch ~/.config/davconf/no-intellij-theme` on a
machine that does not want it.

### mac

`mac/update.sh` writes the macOS defaults a fresh machine gets wrong. Every
setting is compared before it is written, so a machine already in the desired
state changes nothing — and only the apps whose settings changed are restarted,
which is what keeps the daily background run from bouncing Finder or the Dock
for a no-op.

| Setting                     | Value                                        |
| --------------------------- | -------------------------------------------- |
| Finder view style           | list (`FXPreferredViewStyle = Nlsv`)         |
| Hidden files                | visible (`AppleShowAllFiles`)                |
| File extensions             | always shown (`AppleShowAllExtensions`)      |
| Dock                        | hides automatically (`autohide`)             |
| Dock icon size              | 35pt (`tilesize`, slider spans 16–128)       |
| Window buttons + accent     | graphite (`AppleAquaColorVariant`, `AppleAccentColor`) |

The window buttons are the one row worth explaining. They are drawn by the
window server from a private asset set, so Graphite — all three grey — is the
only supported way to change them; actual custom colours would mean injecting
code into every app with SIP off. Apps read the two keys at launch and
otherwise wait for the notification System Settings posts, which `defaults
write` does not, so running apps keep their old buttons until they restart or
you log out. To go back to the standard blue: `defaults delete -g
AppleAquaColorVariant; defaults delete -g AppleAccentColor` — and drop the two
`set_default` lines, or the next run puts them straight back.

```sh
./mac/update.sh                      # apply every tweak
./mac/update.sh --check              # report what differs, change nothing
./mac/update.sh --reset-folder-views # also forget per-folder view settings
```

Finder stores a view style *per folder*, in that folder's `.DS_Store`, and a
saved one wins over the global preference. So list view only takes effect for
folders you have never adjusted by hand. `--reset-folder-views` deletes those
files under `$HOME` so every folder falls back to the default — at the cost of
the icon positions and window sizes saved alongside them. It is opt-in, stays
on the boot volume (`find -xdev`, so external disks and network shares are left
alone), and never runs from the daily auto-update.

To add a tweak, add a `set_default` line to `mac/update.sh` with the domain,
key, type and a short description; the comparison, reporting and app restart
come for free.

### aerospace

`aerospace/update.sh` links `~/.aerospace.toml` to `aerospace/aerospace.toml` in
this repo — the config for [AeroSpace](https://nikitabobko.github.io/AeroSpace),
the tiling window manager installed by `Brewfile.common`. An existing real file
is backed up first, and a link that already points here is left alone.

```sh
./aerospace/update.sh          # link the config
./aerospace/update.sh --check  # report what would change, change nothing
```

Unlike the terminal, a running AeroSpace can be told to re-read its config, so
the script does that itself with `aerospace reload-config` and the change
applies without a restart. A config error surfaces there and then, as AeroSpace's
own message.

AeroSpace reads `~/.aerospace.toml` first and only falls back to
`~/.config/aerospace/aerospace.toml`, so this repo owns the first path — the one
that wins — and the second should stay absent. The script says so if it finds
one being shadowed.

`start-at-login = true`, so AeroSpace comes back after a reboot. AeroSpace
registers that login item when it starts, not when it reloads its config, so
turning it on takes effect from the next launch — `killall AeroSpace && open -a
AeroSpace` if you do not want to wait for a reboot.

The leader key is caps lock, which reaches the config as `ctrl-alt-cmd-`
because that is what `karabiner/` turns it into. `caps+h` focuses left,
`caps+shift+h` moves left, `caps+1` goes to workspace 1, `caps+shift+1` sends
the window there. Held, that is — tapped, caps lock is still caps lock.

It is caps lock rather than plain alt because this is a Swiss German layout,
where the option layer is not spare room — it is where the programming
characters are typed:

| binding | costs | | binding | costs |
|---|---|---|---|---|
| `alt-5` | `[` | | `alt-3` | `#` |
| `alt-6` | `]` | | `alt-g` | `@` |
| `alt-7` | `\|` | | `alt-n` | `~` (dead key) |
| `alt-8` | `{` | | `alt-e` | `€` |
| `alt-9` | `}` | | `alt-equal` | `´` (dead key) |

The workspace bindings for 5 through 9 alone cost all five brackets, and there
is no arranging of them that does not cost something: every letter and digit on
that layer is a character somebody types. Moving the leader off alt is what
gives them all back, and it is why workspaces 3, G and N — dropped one at a
time as their characters were missed — are bound again.

Every `move-node-to-workspace` binding carries `--focus-follows-window`: sending
a window to a workspace takes you with it, rather than leaving you staring at
the space it just left.

`auto-reload-config = false` is left as it was, which is fine — this script
reloads explicitly, and that is more reliable than a file watcher pointed at a
symlink.

### karabiner

`karabiner/update.sh` installs one Karabiner-Elements rule: caps lock held is
cmd+ctrl+alt, which is what makes it usable as AeroSpace's leader. Tapped, it
is still caps lock. It also sets the virtual keyboard to ISO, which is
unrelated to the leader and not optional — see below.

```sh
./karabiner/update.sh          # install the rule where out of date
./karabiner/update.sh --check  # report what would change, change nothing
```

AeroSpace's modifiers are cmd, alt, ctrl and shift, and caps lock is not one of
them. It is not a binding AeroSpace fails to honour either — it is a line it
refuses to parse:

```
[ERROR] mode.main.binding.caps-h: Can't parse modifiers in 'caps-h' binding
```

macOS hands caps lock out below the level any hotkey registration can see, so
no config change reaches it. Karabiner sits lower still, at the event tap,
which is why it can do what the config cannot. Held, caps lock becomes
cmd+ctrl+alt — three modifiers AeroSpace does understand, in a combination
nothing else on the system claims. Not the full hyper of cmd+ctrl+alt+shift,
deliberately: that would swallow shift, and shift is what tells `move` from
`focus`. With three, caps+shift is still a second level.

Caps lock rather than fn, which is what this was before, because fn is not in
the same place twice: bottom left on the built-in keyboard, bottom right on the
Logitech MX Keys S — the hand already on `hjkl` — and a Logitech fn is handled
partly in firmware, so it does not reliably reach Karabiner at all. Caps lock
is on every keyboard, in one place, under the left little finger next to `a`.

Because caps lock has no *second* function worth keeping — unlike fn, where
remapping the key costs fn+arrows for home and end, fn+delete for forward
delete, fn+F1 for a real F-key — the rule can claim the whole key in one
manipulator, rather than enumerating the keys AeroSpace binds and claiming only
those. Shift is `optional: any` rather than mandatory, which is what lets that
one manipulator cover both `caps+h` and `caps+shift+h` and still pass the shift
through.

It does keep the first function: tapped rather than held, caps lock still
toggles caps lock. On a Swiss German layout that is not a courtesy. Shift on
the umlaut keys is taken — `shift+ä` is `à`, `shift+ö` is `é`, `shift+ü` is
`è` — so caps lock is the only way to type Ä Ö Ü, and a leader that swallowed
it would cost the same kind of thing the alt layer would. Hold for the leader,
tap for the lock, which is what the key was always for.

The three modifiers are `lazy`, so holding caps lock and then thinking better
of it emits nothing at all. The tap gets 250ms rather than Karabiner's default
second — long enough for a deliberate tap, short enough that a held leader
ending in nothing does not toggle the lock a beat later — and 100ms of
`hold_down_milliseconds`, because macOS ignores a caps_lock press that is over
as fast as a synthesised one and does nothing at all.

The rule is written to two places, because they do different jobs. The asset
under `~/.config/karabiner/assets/complex_modifications/` is what makes it
visible in the Karabiner UI, where it can be inspected and removed like any
other rule. The copy inside `karabiner.json` is what actually runs — into every
profile, not just the selected one, so switching profile does not silently
switch the leader key off. A re-run replaces what this repo put there before,
matched on a `davconf:` prefix in the description, so its own rule is never
stacked twice and a rule you added yourself is never touched.

The module sets one thing that has nothing to do with the leader key.
Karabiner does not pass the real keyboard through — it grabs it and replays it
on a virtual one, and that virtual keyboard declares what kind of keyboard it
is. Get that declaration wrong and macOS swaps the key left of `1` with the key
left of `Y`: on a Swiss German layout, `§` and `<` come out as each other.
Nothing in the rules causes it and nothing in the rules can fix it. The lever is
`virtual_hid_keyboard.keyboard_type_v2`, set in every profile.

The value that keeps them the right way round is `ansi`, on a keyboard that is
physically ISO. That reads like a mistake, so for the record it was measured
rather than reasoned — setting each value in turn and reading back what the
virtual keyboard reports to the system:

```
ansi   -> alt_handler_id 46      # keys correct
iso    -> alt_handler_id 47      # § and < swapped
jis    -> alt_handler_id 48
```

The likely reason, unverified and worth no more trust than that, is that
Karabiner already applies the ISO swap itself on the way in, so a virtual
keyboard calling itself ISO has macOS apply it a second time — which is no swap
at all.

It is pinned here rather than left alone because it is per-machine state in
`karabiner.json` that the Karabiner UI will happily change, and two machines
quietly disagreeing about it is exactly how this surfaced. Only that one key is
written, so whatever else Karabiner keeps in there survives, and `--check`
reports it as its own line rather than folding it into the rule.

Karabiner reloads on its own when the file changes, so nothing needs
restarting. What no script can do is grant it a driver extension and Input
Monitoring — until that is done in System Settings the rule is installed and
inert, so the module says so when it cannot see Karabiner running.

### chrome

`chrome/theme` is a Chrome theme in the same Synthwave '85 palette as
`ghostty/config` and the greeting — midnight-indigo frame with a magenta and
cyan glow, neon-pink tab text, cyan toolbar icons, and an outrun sun over a
perspective grid on the new-tab page.

```sh
./chrome/update.sh          # rebuild the images if they are out of date
./chrome/update.sh --check  # report what would change, change nothing
```

Chrome loads an unpacked extension only through its own UI — no flag, file or
preference does it — so the first run on a machine prints the one manual step:
chrome://extensions → Developer mode → Load unpacked → `chrome/theme`. After
that the module detects the theme in Chrome's preferences and goes quiet. The
theme stays unpacked, so Chrome reads it from this checkout on every start:
leave the directory where it is, and a `git pull` reaches the browser the next
time it restarts. `touch ~/.config/davconf/no-chrome-theme` on a machine that
does not want it.

The three PNGs are committed so a fresh checkout can load the theme straight
away. They are drawn by `chrome/theme-art.py` — stdlib only, no Pillow — which
`update.sh` re-runs whenever the script is newer than what it produced.

## Terminal greeting

Every new terminal opens with a Synthwave '85 sun and a panel of vitals:
weather, uptime, free disk, battery, outdated Homebrew packages, and how long
ago this machine last updated itself.

```
      ▄▄▄▄▀▀▀▀▀▀▀▀▀▀▄▄▄▄        DAVCONF · SYNTHWAVE '85
   ▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄     ──────────────────────────────
 ▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄   WEATHER  Basel  ☀️ +21°C ↓8km/h
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  UPTIME   3h 54m
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  DISK     1.3Ti free
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀   POWER    100%
   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀     BREW     3 outdated
          ▄▄▄▄▄▄▄▄▄▄            UPDATE   18m ago
╲   ╲   ╲  ╲ ╲│╱ ╱  ╱   ╱   ╱
──────────────┼──────────────   Hack the planet.
```

Startup stays fast (~20ms): weather and the Homebrew check are read from cache
files and refreshed in a detached background job, so nothing networked ever
runs while you wait for a prompt. A value that has never been fetched shows
`…` rather than a guess. Tune it in `~/.zshrc.local`:

```sh
DAVCONF_GREETING=0                 # no greeting
DAVCONF_GREETING_ART=0             # vitals only, skip the sun
DAVCONF_WEATHER_LOCATION=Zurich    # default Basel
```

The sun is generated, not hand-typed — colours come from the same palette as
`config.ghostty`. Edit `zsh/greeting-art.py` and run it to reshape or recolour
it, then paste the output into the `art=( … )` array in `zsh/greeting.zsh`.

## Configuration tiers

The shell config is split three ways by how shareable each part is:

| File                    | Contents                            | In git? |
| ----------------------- | ----------------------------------- | ------- |
| `zsh/zprofile`          | Login-shell `$PATH` — same everywhere | sourced from a block in `~/.zprofile` |
| `zsh/zshrc`             | Shared setup — same on every machine | yes     |
| `zsh/zshrc.privat`      | Personal hosts and project shortcuts | yes     |
| `~/.zshrc.local`        | API keys, per-machine overrides       | **no**  |

`zsh/zshrc` sources the other two if they exist, so a machine missing either
still gets a working shell.

## Secrets

**Nothing secret goes in this repo.** API keys live in `~/.zshrc.local`, which
git ignores. `zsh/zshrc.local.example` is the template; `zsh/update.sh` copies
it into place with mode `600` on the first run.

Copy the real file between machines out of band (password manager, `scp`) —
never through git.
