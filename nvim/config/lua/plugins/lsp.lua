-- Language servers. Three plugins in one file because they are one feature and
-- none of them is useful alone: mason installs the server binaries,
-- nvim-lspconfig knows how to launch each one, and Neovim's own vim.lsp does
-- everything after that.
--
-- Almost nothing here is a plugin API. Since 0.11 the launching, merging and
-- enabling is built into Neovim — `vim.lsp.config()` and `vim.lsp.enable()` —
-- and nvim-lspconfig is reduced to a directory of `lsp/<server>.lua` files on
-- the runtimepath that say where each server's binary is and what a project
-- root looks like for it. That is why the per-server settings in this repo are
-- not here but in `after/lsp/<server>.lua`: `after/` is the standard Vim
-- mechanism for overriding a runtime file a plugin provided, Neovim merges the
-- two, and the file is only read when a buffer of that language opens. Keeping
-- them here would mean building every server's settings table on every start.
--
-- Why mason, when Homebrew is this repo's package manager for everything else:
-- of the four languages this exists for, Angular's server is not in homebrew at
-- all, and `typescript-language-server` would pull brew's own node in alongside
-- the nvm one that zsh/zshrc puts on $PATH. mason installs all of them under
-- ~/.local/share/nvim/mason, using the node already there — the same bargain
-- lazy.nvim makes in init.lua: it owns a tree outside this repo, and the whole
-- install step is a list of names in a config file.
--
-- What that costs is the one guarantee lazy-lock.json gives. Plugin commits are
-- pinned and committed; server versions are whatever mason fetched the day it
-- first ran, and nothing updates them behind your back either. `:Mason` lists
-- what is installed, `u` updates one, `U` updates all.

-- The servers. mason-lspconfig takes nvim-lspconfig's names, not mason's
-- package names, and installs whatever is missing on startup.
local servers = {
  "jdtls",      -- java
  "ts_ls",      -- javascript and typescript
  "angularls",  -- angular templates, and the template side of a component class
  "eslint",     -- the lint rules a project actually configures, as diagnostics
  "html",       -- component templates that are not Angular
  "cssls",      -- component styles
  "jsonls",     -- angular.json, tsconfig.json, package.json — with schemas
}

return {
  -- nvim-lspconfig itself: the `lsp/` directory, plus the place this repo's
  -- own LSP behaviour is set up.
  {
    "neovim/nvim-lspconfig",

    -- Not VeryLazy: a server has to be configured before the buffer that wants
    -- it is read, and BufReadPre is the last moment that is still true.
    event = { "BufReadPre", "BufNewFile" },

    config = function()
      -- Completion capabilities, advertised to every server. blink.cmp asks for
      -- more than Neovim's defaults do — snippet bodies, resolve support, the
      -- extra fields it uses to sort — and a server that is not told will not
      -- send them. Neovim deep-merges this over make_client_capabilities(), so
      -- this adds rather than replaces.
      --
      -- This require is what actually loads blink, which is why its spec in
      -- blink.lua has no lazy trigger: it would be loaded here regardless.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Diagnostics. Neovim shows none of this by default — `virtual_text` and
      -- `signs` are both off out of the box, so an unconfigured LSP setup looks
      -- like it is doing nothing until you land on the line and press something.
      --
      -- The colours are already in colors/synthwave-85.lua: Diagnostic*,
      -- DiagnosticUnderline*, DiagnosticVirtualText* and LspInlayHint are all
      -- defined there. Nothing below picks a colour; it only decides what is
      -- drawn.
      vim.diagnostic.config({
        -- Errors before warnings before hints, so the sign column and the
        -- virtual text show the worst thing on the line rather than the first.
        severity_sort = true,
        underline = true,
        update_in_insert = false,   -- diagnostics that move while you type are noise

        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✖",
            [vim.diagnostic.severity.WARN]  = "▲",
            [vim.diagnostic.severity.INFO]  = "●",
            [vim.diagnostic.severity.HINT]  = "○",
          },
        },

        virtual_text = {
          spacing = 2,
          prefix = "▪",
          -- Only name the server when more than one is attached — which in a
          -- TypeScript buffer is the normal case: ts_ls, eslint and angularls
          -- all have opinions about the same line, and without this you cannot
          -- tell whose rule you are looking at.
          source = "if_many",
        },

        -- rounded to match neo-tree's popup_border_style, so floats in this
        -- config all have the same edge.
        float = { border = "rounded", source = "if_many" },
      })

      -- Buffer-local keymaps, set when a server attaches rather than up front:
      -- a mapping for rename or format on a buffer with no language server
      -- behind it is a mapping that fails.
      --
      -- Most of what you want is already mapped by Neovim itself and is
      -- deliberately not repeated here — `grn` rename, `gra` code action, `grr`
      -- references, `gri` implementation, `grt` type definition, `gO` document
      -- symbols, `K` hover, `<C-s>` signature help in insert mode, `[d` and `]d`
      -- to step through diagnostics. See :help lsp-defaults. What follows is
      -- only what Neovim leaves out.
      -- Which servers have already been reported as still starting. LspAttach
      -- fires once per buffer, so without this, opening a second Java file
      -- announces the same server a second time.
      local announced = {}

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("davconf.lsp", { clear = true }),
        callback = function(ev)
          local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = "LSP: " .. desc })
          end

          -- Neovim routes go-to-definition through 'tagfunc', so <C-]> already
          -- works. gd is the gesture everyone reaches for anyway.
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")

          -- Java needs the two lines above explained. Most servers list
          -- everything they can do in the reply to `initialize`, and from the
          -- moment they attach, gd works. jdtls does not: it declares
          -- references, implementation, typeDefinition and declaration up
          -- front, but registers textDocument/definition and
          -- textDocument/hover *dynamically*, after it has finished reading
          -- the project. Until that registration arrives the gap is real, and
          -- pressing gd gets Neovim's own answer for it — "method
          -- textDocument/definition is not supported by any server", which
          -- reads like this file is wrong rather than like a server that is
          -- still importing a pom. K, mapped by Neovim itself, says the same
          -- about hover.
          --
          -- On a one-class Maven project that window is about a second. On a
          -- real one it is tens of seconds the first time the project is
          -- opened, and `downloadSources` in after/lsp/jdtls.lua — a jar of
          -- sources fetched per dependency — is a good part of why.
          --
          -- There is no statusline in this config to hang vim.lsp.status()
          -- off, so this is the whole report: one line when a server attaches
          -- without go-to-definition, one when it gains it. Servers that
          -- declare it up front never trigger either.
          if not announced[client.id] and not client:supports_method("textDocument/definition") then
            announced[client.id] = true
            vim.notify(client.name .. ": starting — go-to-definition and hover not ready yet")

            local timer = assert(vim.uv.new_timer())
            local waited = 0
            timer:start(500, 500, vim.schedule_wrap(function()
              waited = waited + 500

              local function done(message, level)
                timer:stop()
                timer:close()
                vim.notify(client.name .. ": " .. message, level)
              end

              if client:is_stopped() then
                timer:stop()
                timer:close()
              elseif client:supports_method("textDocument/definition") then
                done(("ready after %.1fs"):format(waited / 1000))
              elseif waited >= 180000 then
                -- Three minutes is past any honest import. Something is wrong
                -- with the project rather than slow about it — :LspLog is
                -- where jdtls says what.
                done("still has no go-to-definition after 3m — see :LspLog", vim.log.levels.WARN)
              end
            end))
          end

          -- <leader>c for code: <leader>f is Telescope and <leader>e is the
          -- explorer, and nothing else in this config claims c.
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")

          -- Inlay hints off by default and toggled, not on: they are genuinely
          -- useful while reading unfamiliar code and genuinely in the way while
          -- writing familiar code, and which of those you are doing is not
          -- something a config file can know.
          if client:supports_method("textDocument/inlayHint") then
            map("<leader>ci", function()
              local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
              vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
            end, "Toggle inlay hints")
          end

          -- Highlight the other occurrences of whatever the cursor is on.
          -- LspReferenceText, LspReferenceRead and LspReferenceWrite are
          -- already defined in the colorscheme; without this nothing ever uses
          -- them.
          if client:supports_method("textDocument/documentHighlight") then
            local group = vim.api.nvim_create_augroup("davconf.lsp.highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              group = group, buffer = ev.buf, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              group = group, buffer = ev.buf, callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })
    end,
  },

  -- The installer. `opts = {}` is not decoration — lazy.nvim only calls
  -- setup() when a spec has opts or a config function, and mason does nothing
  -- at all until it is set up, including putting its bin directory on $PATH.
  {
    "mason-org/mason.nvim",

    -- Every command, not just :Mason. lazy.nvim registers a stub for each name
    -- listed here and nothing for the rest, so with only "Mason" in this list
    -- `:MasonInstall foo` in a fresh session answers "Not an editor command"
    -- until something else has happened to load the plugin.
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonUpdate", "MasonLog" },

    opts = {
      ui = { border = "rounded" },
    },
  },

  -- The bridge. It installs everything in ensure_installed that is missing,
  -- then calls vim.lsp.enable() for every server mason has — so nothing below
  -- has to enable them one by one, and a server installed by hand with :Mason
  -- starts working without being added to the list above.
  --
  -- It only ever enables servers mason installed. A server that came from
  -- somewhere else on $PATH is invisible to it and would need its own
  -- vim.lsp.enable() call.
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    opts = { ensure_installed = servers },
  },
}
