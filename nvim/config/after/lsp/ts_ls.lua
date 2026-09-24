-- JavaScript and TypeScript, layered over nvim-lspconfig's lsp/ts_ls.lua the
-- same way after/lsp/jdtls.lua is — see the note at the top of that file for
-- what after/lsp/ means and why the settings live there.
--
-- Everything that decides *which* TypeScript is used is already handled by
-- nvim-lspconfig and deliberately not repeated: it prefers the project's own
-- node_modules/.bin/typescript-language-server over mason's when the project
-- has one, so a repo pinned to an older TypeScript is analysed by that version
-- rather than by whatever mason last installed.
--
-- In an Angular project this server is not alone: angularls attaches to the
-- same TypeScript buffers, and eslint attaches on top of both. That is
-- intended — ts_ls knows the type system, angularls knows what a template can
-- refer to, eslint knows the project's rules — and it is why diagnostics are
-- configured with `source = "if_many"` in lsp.lua. Without it three servers
-- disagree in the same virtual text with no attribution.

-- Which hints to show when they are toggled on with <leader>ci. The two
-- "WhenArgumentMatchesName"/"WhenTypeMatchesName" switches are off because a
-- hint that repeats the word already on screen — `name: name` — is the reason
-- people turn inlay hints off and never turn them back on.
local inlay_hints = {
  includeInlayParameterNameHints = "literals",
  includeInlayParameterNameHintsWhenArgumentMatchesName = false,
  includeInlayFunctionParameterTypeHints = true,
  includeInlayVariableTypeHints = true,
  includeInlayVariableTypeHintsWhenTypeMatchesName = false,
  includeInlayPropertyDeclarationTypeHints = true,
  includeInlayFunctionLikeReturnTypeHints = true,
  includeInlayEnumMemberValueHints = true,
}

---@type vim.lsp.Config
return {
  settings = {
    typescript = { inlayHints = inlay_hints },
    javascript = { inlayHints = inlay_hints },
  },
}
