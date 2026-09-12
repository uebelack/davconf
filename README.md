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
current — it is idempotent, so run it again after pulling to apply whatever
changed. Each module has its own `update.sh` if you only want that part.

## Modules

| Module      | What it does                                             |
| ----------- | -------------------------------------------------------- |
| `update.sh` | Runs every module below, in order                         |
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
unless you pass `--upgrade`. To add a package, edit the Brewfile — or dump the
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
