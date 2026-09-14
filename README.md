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
| `common`  | Always applied: the bare terminal — vim, lazygit, gnupg, Ghostty, the Nerd Font |
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

### vscode

`vscode/theme` is a colour theme extension in the same Synthwave '85 palette as
`ghostty/config`, the prompt and the Chrome theme — indigo editor, magenta
structure, cyan for what you call, gold for text you wrote, coral for control
flow and anything wrong. The integrated terminal gets the Ghostty palette
verbatim, all sixteen ANSI colours, so the terminal inside the editor and the
terminal beside it are the same terminal.

```sh
./vscode/update.sh          # link it into every editor found
./vscode/update.sh --check  # report what would change, change nothing
```

Both editors scan their extensions directory at startup and follow symlinks, so
a link into `~/.vscode/extensions`, `~/.vscode-insiders/extensions` or
`~/.cursor/extensions` is the whole install — no packaging, no marketplace.
Cursor is a VS Code fork and reads the same extension format, which is why one
directory serves all three. Editing
`vscode/theme/themes/synthwave-85-color-theme.json` reaches the editor on its
next restart.

An editor counts as installed if *any* of its traces exist: the extensions
directory, its `settings.json`, its app bundle in `/Applications` or
`~/Applications`, or its CLI on `$PATH`. The extensions directory alone is not
proof — an editor that has never installed an extension does not have one yet,
and treating that as "not installed" silently skips a perfectly real editor.
The directory is created when it is the piece that is missing.

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

Every `move-node-to-workspace` binding carries `--focus-follows-window`: sending
a window to a workspace takes you with it, rather than leaving you staring at
the space it just left.

`auto-reload-config = false` is left as it was, which is fine — this script
reloads explicitly, and that is more reliable than a file watcher pointed at a
symlink.

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
