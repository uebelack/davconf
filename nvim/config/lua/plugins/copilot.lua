-- GitHub Copilot, as inline suggestions.
--
-- copilot.lua rather than the official github/copilot.vim: this config has no
-- completion engine for Copilot to plug into, and copilot.lua's virtual-text
-- mode is the one that works standalone. It is also lua, so it lazy-loads on
-- InsertEnter like everything else here instead of on startup.
return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",

  opts = {
    panel = { enabled = false },   -- no completion engine to feed; see above

    suggestion = {
      enabled = true,
      auto_trigger = true,
      hide_during_completion = true,
      debounce = 75,

      -- NOT the upstream defaults, which are alt-based (<M-l>, <M-]>, <M-[>).
      -- On the Swiss German layout this repo is built for, plain alt is where
      -- [ ] | { } # @ ~ live — see the Karabiner note in Brewfile.common — so
      -- an alt keymap here either types a bracket or eats one. Control is the
      -- modifier that stays free.
      --
      -- accept, accept_word and dismiss are bound with passthrough by
      -- copilot.lua: with no suggestion on screen the key still does what it
      -- always did, so <C-y> and <C-e> keep inserting the character above and
      -- below. next and prev are NOT — they are bound unconditionally, so
      -- whatever they are given stops doing its old job entirely. That rules
      -- out <C-k>, which is digraph entry, and <C-j>, which is a newline.
      -- Control plus an arrow has no insert-mode meaning to lose, and cycling
      -- is a navigation gesture anyway.
      keymap = {
        accept      = "<C-y>",      -- the conventional accept
        accept_word = "<C-l>",      -- one more word of it
        accept_line = false,
        next        = "<C-Down>",
        prev        = "<C-Up>",
        dismiss     = "<C-e>",      -- the conventional cancel
      },
    },

    -- Suggestions are off where they cannot help and would only cover text:
    -- prompts, pickers, the tree, and anything secret-shaped.
    filetypes = {
      ["."] = false,
      gitcommit = false,
      gitrebase = false,
      help = false,
      markdown = true,
      ["neo-tree"] = false,
      TelescopePrompt = false,
      ["dap-repl"] = false,
    },
  },
}
