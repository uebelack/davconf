# davconf

My machine configuration, in modules. Everything here is idempotent — re-running
an installer updates rather than reinstalls.

## Setup on a new machine

```sh
git clone git@github.com:uebelack/davconf.git ~/.davconf
cd ~/.davconf
./install.sh              # core setup
./install.sh dev personal # …or with extra package profiles
```

Then fill in `~/.zshrc.local` and open a new shell.

## Modules

| Module             | What it does                                          |
| ------------------ | ----------------------------------------------------- |
| `install_basis.sh` | Installs Homebrew                                      |
| `brew/`            | Package lists (Brewfiles), split into profiles         |
| `zsh/`             | oh-my-zsh, spaceship prompt, plugins, shared `.zshrc`  |

### brew

Packages live in [Brewfiles](https://docs.brew.sh/Brew-Bundle-and-Brewfile),
split so a work machine need not install personal apps:

| File                | Contents                                             |
| ------------------- | ---------------------------------------------------- |
| `Brewfile`          | Core — always installed                               |
| `Brewfile.zsh`      | Shell dependencies (`zsh/install.sh` installs these)   |
| `Brewfile.dev`      | Toolchains, cloud CLIs, GUI dev tools                 |
| `Brewfile.personal` | Personal machines only                                |

```sh
./brew/install.sh                 # core only
./brew/install.sh dev personal    # core + the named profiles
./brew/install.sh --all           # everything
./brew/install.sh --check --all   # what is missing? install nothing
```

Missing packages get installed; existing ones stay at their current version
unless you pass `--upgrade`. To add a package, edit the Brewfile — or dump the
current machine's state with `brew bundle dump --file=- ` and cherry-pick.
Note that `dump` omits formulae installed from custom taps, so check its output
before trusting it.

### zsh

`zsh/install.sh` installs:

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
git ignores. `zsh/zshrc.local.example` is the template; the installer copies it
into place with mode `600` on first run.

Copy the real file between machines out of band (password manager, `scp`) —
never through git.
