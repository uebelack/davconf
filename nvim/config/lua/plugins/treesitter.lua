-- nvim-treesitter — a real parse tree per buffer, which is what turns
-- Telescope's preview pane from plain text into highlighted source. It also
-- replaces Vim's regex highlighting in the buffer itself.
--
-- Parsers are compiled C, built on this machine the first time each language
-- is seen, into ~/.local/share/nvim/lazy/nvim-treesitter/parser. That needs a
-- compiler — on macOS the Xcode command line tools, which `git` has already
-- pulled in on any machine this repo has run on. Nothing lands in this repo.
return {
  "nvim-treesitter/nvim-treesitter",

  -- master is the branch the `nvim-treesitter.configs` API below belongs to.
  -- The `main` branch is an in-progress rewrite with a different, smaller API
  -- and no ensure_installed — pinning here means a :Lazy update cannot move
  -- this onto it and break the setup call.
  branch = "master",

  -- Rebuild the parsers whenever the plugin itself moves: a parser built
  -- against the old runtime and loaded by the new one crashes nvim rather
  -- than degrading, and the failure looks nothing like its cause.
  build = ":TSUpdate",

  -- Not lazy on a key the way Telescope is — highlighting has to be there the
  -- moment a file appears, so the trigger is opening one. VeryLazy would show
  -- the buffer unhighlighted first and then repaint it.
  event = { "BufReadPost", "BufNewFile" },

  opts = {
    -- The languages this repo is actually made of, plus the ones every repo
    -- has. Anything else is a :TSInstall away and does not need to be listed
    -- here — this is the set worth having on a fresh machine without asking.
    ensure_installed = {
      "bash", "c", "diff", "git_config", "gitcommit", "gitignore",
      "json", "lua", "luadoc", "markdown", "markdown_inline",
      "query", "toml", "vim", "vimdoc", "xml", "yaml",
    },

    -- Compile missing parsers in the background rather than blocking the
    -- first open of an unfamiliar filetype.
    auto_install = true,

    highlight = {
      enable = true,
      -- Vim's own regex highlighting stays off. Running both means every
      -- token is highlighted twice, which is slower and, where the two
      -- disagree, visibly wrong.
      additional_vim_regex_highlighting = false,
    },

    indent = { enable = true },
  },

  -- master's entry point is nvim-treesitter.configs, not the plugin module,
  -- so lazy.nvim's default of require("nvim-treesitter").setup(opts) would
  -- call the wrong thing and silently configure nothing.
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
