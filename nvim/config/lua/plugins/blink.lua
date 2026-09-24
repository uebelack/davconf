-- blink.cmp — the completion menu the language servers in lsp.lua feed.
--
-- Until now this config had none, which is why copilot.lua is set up in
-- virtual-text mode: there was nothing for Copilot to plug into. That has not
-- changed. Copilot still draws its suggestion as dimmed text ahead of the
-- cursor and is still accepted with its own key; blink draws a menu of what the
-- language server knows and is accepted with a different one. They are two
-- sources with two gestures, deliberately — see the keymap below.
--
-- The fuzzy matcher is Rust. `version = "1.*"` is what makes that free: the
-- release tags carry prebuilt binaries for every platform, so nothing here
-- needs cargo. Without the version pin lazy.nvim would track the default
-- branch, find no binary, and need `build = "cargo build --release"` and a Rust
-- toolchain this repo does not install. Note that the default branch is also
-- where blink's v2 is being built, which additionally requires a separate
-- blink.lib plugin — one more reason the pin is not optional.
--
-- No lazy trigger on purpose. lsp.lua asks blink for the completion
-- capabilities to advertise to servers, at BufReadPre, before anything has
-- entered insert mode — so an `event = "InsertEnter"` here would be a lie that
-- lazy.nvim quietly resolves by loading it anyway.
return {
  "saghen/blink.cmp",
  version = "1.*",

  -- The snippets source below has nothing to offer without these: friendly-snippets
  -- is the VS Code snippet collection, which is where the java/html/ts snippets
  -- come from.
  dependencies = { "rafamadriz/friendly-snippets" },

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- preset = "none", and every key spelled out, because all four of blink's
    -- presets bind <C-e> and <C-y> — and both of those are already copilot.lua's,
    -- for reasons that took a paragraph of nvim/config/lua/plugins/copilot.lua
    -- to arrive at and are not worth re-litigating for a completion menu. The
    -- presets also bind <C-k>, which is digraph entry.
    --
    -- So the split is: <C-y> accepts what Copilot wrote, <CR> accepts what the
    -- language server suggested. Every mapping ends in "fallback", so with no
    -- menu open each key still does what it always did — <CR> is a newline,
    -- <Tab> indents, <C-n> and <C-p> are Vim's own keyword completion.
    keymap = {
      preset = "none",
      ["<C-n>"]     = { "show", "select_next", "fallback" },
      ["<C-p>"]     = { "select_prev", "fallback" },
      ["<CR>"]      = { "accept", "fallback" },
      ["<Tab>"]     = { "snippet_forward", "fallback" },
      ["<S-Tab>"]   = { "snippet_backward", "fallback" },
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation", "fallback" },
      ["<C-c>"]     = { "cancel", "fallback" },
    },

    appearance = {
      -- The Nerd Font in Brewfile.common is a "mono" variant — its glyphs are
      -- one cell wide. Telling blink otherwise makes every icon in the menu
      -- overlap the text beside it by half a character.
      nerd_font_variant = "mono",
    },

    completion = {
      menu = {
        border = "rounded",   -- as neo-tree and the diagnostic floats
        -- Nothing here sets colours: blink's own groups link to Pmenu,
        -- PmenuSel, PmenuKind and PmenuMatch, which colors/synthwave-85.lua
        -- already defines. The menu is in palette without being mentioned by it.
      },

      documentation = {
        -- Shown without being asked for, but late enough that scrolling the
        -- list does not flash a window on every item.
        auto_show = true,
        auto_show_delay_ms = 250,
        window = { border = "rounded" },
      },

      -- Off, and this is the important one. blink's ghost text and copilot.lua's
      -- virtual text are the same pixels: both draw the completion inline after
      -- the cursor. With both on you get two suggestions stacked on one line and
      -- no way to tell which key takes which.
      ghost_text = { enabled = false },
    },

    -- The signature window, for the parameter you are currently inside. Neovim
    -- maps <C-s> in insert mode to ask for this; blink shows it as you type the
    -- opening paren without being asked.
    signature = {
      enabled = true,
      window = { border = "rounded" },
    },

    sources = {
      -- In priority order. buffer is last because in a Java or TypeScript file
      -- every word in it is also a word the language server knows, spelled
      -- better — it is there for comments, strings and filetypes with no server.
      default = { "lsp", "path", "snippets", "buffer" },
    },

    fuzzy = {
      -- The prebuilt Rust matcher, with the Lua one as a fallback that says so.
      -- "prefer_rust" alone would fall back silently, which turns "why is this
      -- slow" into an unanswerable question.
      implementation = "prefer_rust_with_warning",
    },
  },

  -- So a later spec can add a source without restating the list above.
  opts_extend = { "sources.default" },
}
