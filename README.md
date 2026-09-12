# davconf

My machine configuration, in modules. Run `./update.sh` to set a machine up,
and again whenever you want it back in sync with this repo.

## Setup, and keeping machines in sync

```sh
git clone git@github.com:uebelack/davconf.git ~/.davconf
cd ~/.davconf
./update.sh              # core setup
./update.sh dev privat   # …or with extra package profiles
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
DAVCONF_UPDATE_PROFILES="dev privat"   # brew profiles to include
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

The pull is skipped when the working tree is dirty or history has diverged; it
is `--ff-only`, so it never touches local work. `./update.sh --no-pull` skips it.

One manual step on a brand-new machine: Homebrew keeps third-party tap trust in
`~/.homebrew/trust.json`, which no Brewfile can set, so `Brewfile.dev` needs

```sh
brew trust --tap arthur-ficial/tap
```

## Modules

| Module      | What it does                                             |
| ----------- | -------------------------------------------------------- |
| `update.sh` | Pulls this repo, then runs every module below, in order    |
| `brew/`     | Homebrew itself, plus package lists split into profiles   |
| `zsh/`      | oh-my-zsh, spaceship prompt, plugins, shared `.zshrc`     |

### brew

`brew/update.sh` installs Homebrew first if the machine does not have it.
Packages live in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
split so a work machine need not install personal apps:

| File                | Contents                                             |
| ------------------- | ---------------------------------------------------- |
| `Brewfile`          | Core — always installed                               |
| `Brewfile.zsh`      | Shell dependencies (`zsh/update.sh` installs these)   |
| `Brewfile.dev`      | Toolchains, cloud CLIs, GUI dev tools                 |
| `Brewfile.privat`   | Personal machines only                                |

```sh
./brew/update.sh                 # core only
./brew/update.sh dev privat      # core + the named profiles
./brew/update.sh --all           # everything
./brew/update.sh --check --all   # what is missing? install nothing
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

To add a package, edit the Brewfile — or dump the
current machine's state with `brew bundle dump --file=- ` and cherry-pick.
Note that `dump` omits formulae installed from custom taps, so check its output
before trusting it.

### zsh

`zsh/update.sh` installs, and on later runs updates:

- Homebrew packages the shell hooks into: `nvm`, `rbenv`, `pyenv-virtualenv`,
  `jenv`, `direnv`, `lazygit`, `gnupg`, `neovim`
- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)
- [spaceship-prompt](https://github.com/spaceship-prompt/spaceship-prompt) theme
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- a symlink `~/.zshrc` -> `zsh/zshrc` (any existing file is backed up first)
- `zsh/autoupdate.zsh`, the daily background refresh described above

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
