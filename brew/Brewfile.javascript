# JavaScript / TypeScript toolchain.
#
# bun and pnpm install themselves outside Homebrew; zshrc puts them on $PATH.

brew "nvm"         # zshrc sources it from /opt/homebrew/opt/nvm
brew "serve"       # static http server
brew "vite-plus"   # web dev toolchain
