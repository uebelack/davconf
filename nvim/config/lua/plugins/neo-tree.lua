-- neo-tree — the project sidebar, for navigating a tree and opening what you
-- find in it.
--
-- This is deliberately not the same job as Telescope. Telescope answers "where
-- is the file I am already thinking of"; neo-tree answers "what is in here".
-- Reaching for the wrong one of those is what makes people believe they do not
-- need a file explorer — or do not need a fuzzy finder.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    -- Glyphs come from the Nerd Font in brew/Brewfile.common. Ghostty is set
    -- to JetBrains Mono and falls back to it for anything it does not have,
    -- so the icons render without the terminal font having to change.
    "nvim-tree/nvim-web-devicons",
  },

  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>",           desc = "Explorer: toggle" },
    { "<leader>E", "<cmd>Neotree reveal<cr>",           desc = "Explorer: reveal current file" },
    { "<leader>ge", "<cmd>Neotree git_status<cr>",      desc = "Explorer: git status" },
    { "<leader>be", "<cmd>Neotree buffers<cr>",         desc = "Explorer: open buffers" },
  },

  -- netrw is what answers `nvim .` and `:e some/dir`. Left alone it opens its
  -- own directory listing over the top of this, so it is switched off and
  -- neo-tree takes the handler instead.
  --
  -- The catch is that this plugin is lazy: on `nvim .` the directory buffer
  -- exists before anything has pressed <leader>e, so there is nothing loaded
  -- to hijack it and the result is an empty buffer and no explorer. Loading
  -- it here, and only when nvim was actually started on a directory, is what
  -- closes that gap without giving up lazy-loading for every other start.
  init = function()
    if vim.fn.argc(-1) == 1 then
      local stat = (vim.uv or vim.loop).fs_stat(vim.fn.argv(0))
      if stat and stat.type == "directory" then
        require("neo-tree")
      end
    end
    vim.g.loaded_netrwPlugin = 1
  end,

  opts = {
    close_if_last_window = true,
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,

    default_component_configs = {
      indent = { with_expanders = true, indent_size = 2 },
      git_status = {
        symbols = {
          added = "+", modified = "~", deleted = "-", renamed = "→",
          untracked = "?", ignored = "◌", unstaged = "•", staged = "✓", conflict = "!",
        },
      },
    },

    window = {
      position = "left",
      width = 34,
      mappings = {
        ["<space>"] = "none",   -- the leader key; neo-tree may not have it
        ["l"] = "open",
        ["h"] = "close_node",
        ["<cr>"] = "open",
        ["s"] = "open_split",
        ["v"] = "open_vsplit",
      },
    },

    filesystem = {
      -- Open the tree on the file you are in, so the sidebar is never showing
      -- a part of the project you left ten minutes ago.
      follow_current_file = { enabled = true, leave_dirs_open = false },
      use_libuv_file_watcher = true,
      hijack_netrw_behavior = "open_default",

      filtered_items = {
        -- Dotfiles shown, for the same reason Telescope's find_files shows
        -- them: in a config repo, hiding them hides most of the repo. .git
        -- and friends stay hidden — that is noise, not config.
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = true,
        hide_by_name = { ".git", ".DS_Store", "node_modules" },
      },
    },
  },
}
