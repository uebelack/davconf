-- Neovim configuration. Reached through a symlink: ~/.config/nvim points at
-- nvim/config in this repo, created by nvim/update.sh.
--
-- Plugins are managed by lazy.nvim, which is deliberately not a Homebrew
-- entry. It bootstraps itself from git on first start into
-- ~/.local/share/nvim/lazy, which is also where it puts every plugin — so
-- nothing a plugin manager owns ever lands in this repo except the lockfile
-- below. The clone at the bottom of this file is the whole install step.

-- The leader has to be set before lazy.nvim loads a single spec. A plugin
-- that maps <leader>ff resolves the leader at map time, so setting it later
-- binds those keys to the old leader (a backslash) and the mappings quietly
-- end up somewhere nobody presses.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  -- Prepending a path that does not exist would fail later, inside
  -- require("lazy"), with a message about a missing module rather than about
  -- the network. Say what actually went wrong instead.
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Could not clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress a key to continue without plugins." },
    }, true, {})
    vim.fn.getchar()
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Every file under lua/plugins returns one spec. Adding a plugin is adding
  -- a file there; nothing here has to be touched.
  spec = { { import = "plugins" } },

  -- lazy-lock.json defaults to stdpath("config"), which through the symlink
  -- is nvim/config in this repo — so the exact plugin commits are committed
  -- and every machine ends up on the same ones instead of on whatever was
  -- HEAD the day it first opened nvim. Run :Lazy update, then commit it.

  -- No update check on startup. It is a network round trip in the path
  -- between pressing the key and seeing the file, and this repo already has
  -- one thing that does the updating: ./update.sh.
  checker = { enabled = false },
  change_detection = { notify = false },
})
