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
| `zsh/`      | oh-my-zsh, spaceship prompt, plugins, shared `.zshrc`     |
| `mac/`      | macOS system defaults — the settings a fresh Mac gets wrong |

### brew

`brew/update.sh` installs Homebrew first if the machine does not have it.
Packages live in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
split into profiles so each machine installs only what it is actually for:

| Profile   | Contents                                                   |
| --------- | ---------------------------------------------------------- |
| `common`  | Always applied: the bare terminal — neovim, lazygit, gnupg, Ghostty, the Nerd Font |
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

The daily auto-update passes `--upgrade`, so the machine keeps itself current
on its own. Set `DAVCONF_UPDATE_UPGRADE=0` in `~/.zshrc.local` to install
missing packages but upgrade nothing.

To add a package, edit the right Brewfile — or dump the current machine's state
with `brew bundle dump --file=-` and cherry-pick. Note that `dump` omits
formulae installed from custom taps, so check its output before trusting it.

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
- a symlink `~/.zshrc` -> `zsh/zshrc` (any existing file is backed up first)
- `zsh/autoupdate.zsh`, the daily background refresh described above

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
