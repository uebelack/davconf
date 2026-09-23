-- Telescope — fuzzy finder over files, grep results, buffers and help.
--
-- It shells out for the two that matter: live_grep needs ripgrep, find_files
-- prefers fd. Both are in brew/Brewfile.common. Without them Telescope still
-- works, it just falls back to `grep` and `find` and feels broken on any repo
-- large enough to want a fuzzy finder in the first place.
return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = { "nvim-lua/plenary.nvim" },

  -- cmd and keys together are what make this lazy: nothing of Telescope is
  -- loaded until one of these is used, so it costs nothing at startup.
  cmd = "Telescope",
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Telescope: find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Telescope: live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Telescope: buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>",  desc = "Telescope: help tags" },
  },

  opts = {
    defaults = {
      -- find_files skips dotfiles by default, which in a config repo hides
      -- most of what you are looking for. .git is still excluded, otherwise
      -- the picker is nothing but object files.
      file_ignore_patterns = { "^%.git/" },
    },
    pickers = {
      find_files = { hidden = true },
    },
  },
}
