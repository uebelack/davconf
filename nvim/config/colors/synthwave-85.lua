-- ╔══════════════════════════════════════════════════════════════╗
-- ║   N E O V I M  ::  S Y N T H W A V E   ' 8 5                  ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- The palette of ghostty/config, zsh/colors.zsh, chrome/theme and the two
-- editor themes in this repo. The roles are the same everywhere, and that is
-- the whole point of keeping them in one repo:
--
--   cyan     what you call — functions, methods, links
--   gold     text you wrote — strings, attribute values
--   magenta  structure and control flow — keywords, storage, what decides
--   coral    punctuation and operators, and separately: anything wrong
--   green    types and classes
--   orange   literals — numbers, constants, escapes, regex
--   lavender variables
--   dim      what you can skim past — comments, line numbers, inactive text
--
-- Note that magenta and coral were swapped in this repo: keywords used to be
-- coral and punctuation magenta. If this file ever disagrees with
-- vscode/theme or intellij/theme about which is which, they are the ones that
-- moved and this is the one to fix.
--
-- Load with `:colorscheme synthwave-85`. init.lua does it on startup.

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.o.background = "dark"
vim.g.colors_name = "synthwave-85"

local p = {
  -- Backgrounds, darkest first. The VS Code theme uses the same eight, so a
  -- split between nvim and an editor window does not look like two products.
  abyss   = "#0a0518",
  shadow  = "#120a25",
  deep    = "#150d2b",
  bg      = "#1a1033",
  raised  = "#1c1238",
  float   = "#241b3a",
  line    = "#2f2350",
  border  = "#3b3163",

  -- Text, brightest first.
  white   = "#ffffff",
  fg      = "#d4c8ff",
  muted   = "#c3b6ef",
  dim     = "#9d7fd0",
  faint   = "#6e5c96",
  comment = "#495495",

  -- The neons. Same sixteen as the Ghostty palette.
  coral      = "#fe4450",
  coral_br   = "#ff6e6e",
  green      = "#72f1b8",
  green_br   = "#a6ffcb",
  gold       = "#fede5d",
  gold_br    = "#fff59d",
  blue       = "#03edf9",
  blue_br    = "#6effff",
  magenta    = "#ff7edb",
  magenta_br = "#ffb8f3",
  hotpink    = "#f92aad",
  cyan       = "#00f0ff",
  aqua       = "#8bfff5",
  orange     = "#ff8b39",
}

-- The VS Code theme writes its washes as eight-digit hex — #ff7edb33 is
-- magenta at 20% over whatever is behind it. Neovim highlights have no alpha
-- channel, so the same colours have to be mixed down to opaque here. Doing it
-- in code rather than pasting the results keeps the intent readable: this is
-- "magenta at 20%", not "#482655".
local function blend(fg, bg, alpha)
  local function parts(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  end
  local fr, fg_, fb = parts(fg)
  local br, bg_, bb = parts(bg)
  return string.format("#%02x%02x%02x",
    math.floor(br + (fr - br) * alpha + 0.5),
    math.floor(bg_ + (fg_ - bg_) * alpha + 0.5),
    math.floor(bb + (fb - bb) * alpha + 0.5))
end

local wash = {
  selection   = blend(p.magenta, p.bg, 0.20),   -- editor.selectionBackground
  selection_n = blend(p.magenta, p.bg, 0.10),   -- inactive selection
  pick        = blend(p.hotpink, p.bg, 0.20),   -- list.activeSelectionBackground
  search      = blend(p.gold, p.bg, 0.20),      -- findMatchHighlight
  search_cur  = blend(p.orange, p.bg, 0.40),    -- findMatch
  word        = blend(p.cyan, p.bg, 0.12),      -- wordHighlight
  word_strong = blend(p.green, p.bg, 0.12),
  cursorline  = blend(p.white, p.bg, 0.04),     -- editor.lineHighlightBackground
  added       = blend(p.green, p.bg, 0.15),
  removed     = blend(p.coral, p.bg, 0.15),
  changed     = blend(p.gold, p.bg, 0.12),
  changed_txt = blend(p.gold, p.bg, 0.25),
  err_bg      = "#3a0f1e",                      -- inputValidation.errorBackground
  warn_bg     = "#3a2f12",                      -- inputValidation.warningBackground
}

local hl = {
  ---------------------------------------------------------------------------
  -- Editor chrome
  ---------------------------------------------------------------------------
  Normal       = { fg = p.fg, bg = p.bg },
  NormalNC     = { fg = p.fg, bg = p.bg },
  NormalFloat  = { fg = p.fg, bg = p.float },
  FloatBorder  = { fg = p.border, bg = p.float },
  FloatTitle   = { fg = p.magenta, bg = p.float, bold = true },
  FloatFooter  = { fg = p.faint, bg = p.float },

  ColorColumn  = { bg = p.deep },
  Conceal      = { fg = p.faint },
  Cursor       = { fg = p.bg, bg = p.cyan },
  lCursor      = { fg = p.bg, bg = p.cyan },
  CursorIM     = { fg = p.bg, bg = p.cyan },
  TermCursor   = { fg = p.bg, bg = p.cyan },
  CursorColumn = { bg = wash.cursorline },
  CursorLine   = { bg = wash.cursorline },
  CursorLineNr = { fg = p.magenta, bold = true },
  LineNr       = { fg = p.comment },
  LineNrAbove  = { fg = p.comment },
  LineNrBelow  = { fg = p.comment },
  SignColumn   = { fg = p.comment, bg = p.bg },
  FoldColumn   = { fg = p.comment, bg = p.bg },
  Folded       = { fg = p.dim, bg = p.raised },
  EndOfBuffer  = { fg = p.bg },            -- no ~ column; the eye does not need it
  Directory    = { fg = p.cyan },
  Title        = { fg = p.magenta, bold = true },

  -- editorGroup.border in the VS Code theme: present, but not a feature.
  WinSeparator = { fg = p.line, bg = p.bg },
  VertSplit    = { fg = p.line, bg = p.bg },

  MatchParen   = { fg = p.cyan, bold = true, underline = true },
  NonText      = { fg = p.line },
  SpecialKey   = { fg = p.line },
  Whitespace   = { fg = p.line },

  Visual       = { bg = wash.selection },
  VisualNOS    = { bg = wash.selection_n },

  Search       = { bg = wash.search, fg = p.fg },
  IncSearch    = { bg = wash.search_cur, fg = p.bg, bold = true },
  CurSearch    = { bg = p.orange, fg = p.bg, bold = true },
  Substitute   = { bg = p.coral, fg = p.bg },
  QuickFixLine = { bg = wash.pick },

  -- The completion popup. suggestWidget in the VS Code theme, down to the
  -- cyan on the characters that actually matched what you typed.
  Pmenu        = { fg = p.fg, bg = p.raised },
  PmenuSel     = { bg = wash.pick, bold = true },
  PmenuKind    = { fg = p.green, bg = p.raised },
  PmenuKindSel = { fg = p.green, bg = wash.pick },
  PmenuExtra   = { fg = p.faint, bg = p.raised },
  PmenuExtraSel= { fg = p.dim, bg = wash.pick },
  PmenuSbar    = { bg = p.raised },
  PmenuThumb   = { bg = p.border },
  PmenuMatch   = { fg = p.cyan, bg = p.raised, bold = true },
  PmenuMatchSel= { fg = p.cyan, bg = wash.pick, bold = true },
  WildMenu     = { fg = p.bg, bg = p.magenta },

  StatusLine   = { fg = p.fg, bg = p.float },
  StatusLineNC = { fg = p.faint, bg = p.deep },
  WinBar       = { fg = p.magenta, bg = p.bg, bold = true },
  WinBarNC     = { fg = p.faint, bg = p.bg },
  TabLine      = { fg = p.faint, bg = p.deep },
  TabLineFill  = { bg = p.deep },
  TabLineSel   = { fg = p.magenta, bg = p.bg, bold = true },

  MsgArea      = { fg = p.fg },
  MsgSeparator = { fg = p.line, bg = p.bg },
  ModeMsg      = { fg = p.magenta, bold = true },
  MoreMsg      = { fg = p.cyan },
  Question     = { fg = p.cyan },
  ErrorMsg     = { fg = p.coral, bold = true },
  WarningMsg   = { fg = p.gold },

  SpellBad     = { sp = p.coral, undercurl = true },
  SpellCap     = { sp = p.gold, undercurl = true },
  SpellLocal   = { sp = p.cyan, undercurl = true },
  SpellRare    = { sp = p.magenta, undercurl = true },

  ---------------------------------------------------------------------------
  -- Syntax, the old vim groups. Everything below in the treesitter block
  -- links back to these where it can, so a filetype with no parser still
  -- comes out in the right colours instead of falling back to defaults.
  ---------------------------------------------------------------------------
  Comment        = { fg = p.comment, italic = true },

  Constant       = { fg = p.orange },
  String         = { fg = p.gold },
  Character      = { fg = p.gold },
  Number         = { fg = p.orange },
  Boolean        = { fg = p.orange },
  Float          = { fg = p.orange },

  Identifier     = { fg = p.fg },
  Function       = { fg = p.cyan },

  -- Control flow is magenta. This is the half of the swap that moved.
  Statement      = { fg = p.magenta },
  Conditional    = { fg = p.magenta },
  Repeat         = { fg = p.magenta },
  Label          = { fg = p.magenta },
  Keyword        = { fg = p.magenta },
  Exception      = { fg = p.magenta },

  -- …and punctuation is coral. The other half.
  Operator       = { fg = p.coral },
  Delimiter      = { fg = p.coral },

  PreProc        = { fg = p.orange },
  Include        = { fg = p.magenta },
  Define         = { fg = p.orange },
  Macro          = { fg = p.orange },
  PreCondit      = { fg = p.orange },

  Type           = { fg = p.green },
  StorageClass   = { fg = p.magenta },
  Structure      = { fg = p.green },
  Typedef        = { fg = p.green },

  Special        = { fg = p.orange },
  SpecialChar    = { fg = p.orange },
  SpecialComment = { fg = p.dim, italic = true },
  Tag            = { fg = p.coral },
  Debug          = { fg = p.coral },

  Underlined     = { fg = p.cyan, underline = true },
  Ignore         = { fg = p.faint },
  Error          = { fg = p.coral, bg = wash.err_bg, bold = true },
  Todo           = { fg = p.bg, bg = p.gold, bold = true },

  Added          = { fg = p.green },
  Changed        = { fg = p.gold },
  Removed        = { fg = p.coral },

  ---------------------------------------------------------------------------
  -- Diff
  ---------------------------------------------------------------------------
  DiffAdd    = { bg = wash.added },
  DiffChange = { bg = wash.changed },
  DiffDelete = { bg = wash.removed, fg = p.coral },
  DiffText   = { bg = wash.changed_txt, bold = true },

  ---------------------------------------------------------------------------
  -- Diagnostics
  ---------------------------------------------------------------------------
  DiagnosticError = { fg = p.coral },
  DiagnosticWarn  = { fg = p.gold },
  DiagnosticInfo  = { fg = p.cyan },
  DiagnosticHint  = { fg = p.aqua },
  DiagnosticOk    = { fg = p.green },

  DiagnosticUnderlineError = { sp = p.coral, undercurl = true },
  DiagnosticUnderlineWarn  = { sp = p.gold, undercurl = true },
  DiagnosticUnderlineInfo  = { sp = p.cyan, undercurl = true },
  DiagnosticUnderlineHint  = { sp = p.aqua, undercurl = true },
  DiagnosticUnderlineOk    = { sp = p.green, undercurl = true },

  -- Virtual text sits in the same line as code, so it is dimmed rather than
  -- given the full neon — otherwise a file with a few warnings in it reads as
  -- a wall of gold and the code stops being the loudest thing on screen.
  DiagnosticVirtualTextError = { fg = p.coral, bg = wash.removed },
  DiagnosticVirtualTextWarn  = { fg = p.gold, bg = wash.changed },
  DiagnosticVirtualTextInfo  = { fg = p.cyan, bg = wash.word },
  DiagnosticVirtualTextHint  = { fg = p.aqua, bg = wash.word },
  DiagnosticVirtualTextOk    = { fg = p.green, bg = wash.added },

  DiagnosticDeprecated  = { fg = p.faint, strikethrough = true },
  DiagnosticUnnecessary = { fg = p.faint },

  ---------------------------------------------------------------------------
  -- LSP
  ---------------------------------------------------------------------------
  LspReferenceText          = { bg = wash.word },
  LspReferenceRead          = { bg = wash.word },
  LspReferenceWrite         = { bg = wash.word_strong },
  LspSignatureActiveParameter = { fg = p.cyan, bold = true },
  LspInlayHint              = { fg = p.faint, bg = p.raised, italic = true },
  LspCodeLens               = { fg = p.faint, italic = true },
  LspCodeLensSeparator      = { fg = p.line },

  ---------------------------------------------------------------------------
  -- Treesitter. The capture names Neovim 0.10+ uses; the older @-groups
  -- without a dot still work because they are the prefix of these.
  ---------------------------------------------------------------------------
  ["@comment"]              = { link = "Comment" },
  ["@comment.documentation"]= { fg = p.dim, italic = true },
  ["@comment.error"]        = { fg = p.bg, bg = p.coral, bold = true },
  ["@comment.warning"]      = { fg = p.bg, bg = p.gold, bold = true },
  ["@comment.todo"]         = { fg = p.bg, bg = p.cyan, bold = true },
  ["@comment.note"]         = { fg = p.bg, bg = p.aqua, bold = true },

  ["@constant"]             = { fg = p.orange },
  ["@constant.builtin"]     = { fg = p.orange },
  ["@constant.macro"]       = { fg = p.orange },

  ["@string"]               = { fg = p.gold },
  ["@string.documentation"] = { fg = p.gold },
  -- Regex and escapes stay orange rather than gold: inside a string they have
  -- to be findable, and gold-on-gold is exactly the case where an escape gets
  -- missed.
  ["@string.regexp"]        = { fg = p.orange },
  ["@string.escape"]        = { fg = p.orange },
  ["@string.special"]       = { fg = p.orange },
  ["@string.special.url"]   = { fg = p.cyan, underline = true },
  ["@string.special.path"]  = { fg = p.aqua },
  ["@string.special.symbol"]= { fg = p.orange },

  ["@character"]            = { fg = p.gold },
  ["@character.special"]    = { fg = p.orange },
  ["@number"]               = { fg = p.orange },
  ["@number.float"]         = { fg = p.orange },
  ["@boolean"]              = { fg = p.orange },

  ["@function"]             = { fg = p.cyan },
  ["@function.builtin"]     = { fg = p.cyan },
  ["@function.call"]        = { fg = p.cyan },
  ["@function.macro"]       = { fg = p.orange },
  ["@function.method"]      = { fg = p.cyan },
  ["@function.method.call"] = { fg = p.cyan },
  ["@constructor"]          = { fg = p.green },

  -- Coral, post-swap.
  ["@operator"]             = { fg = p.coral },
  ["@punctuation.delimiter"]= { fg = p.coral },
  ["@punctuation.bracket"]  = { fg = p.coral },
  ["@punctuation.special"]  = { fg = p.magenta },

  -- Magenta, post-swap.
  ["@keyword"]              = { fg = p.magenta },
  ["@keyword.function"]     = { fg = p.magenta },
  ["@keyword.operator"]     = { fg = p.magenta },
  ["@keyword.import"]       = { fg = p.magenta },
  ["@keyword.type"]         = { fg = p.magenta },
  ["@keyword.modifier"]     = { fg = p.magenta },
  ["@keyword.repeat"]       = { fg = p.magenta },
  ["@keyword.return"]       = { fg = p.magenta },
  ["@keyword.exception"]    = { fg = p.magenta },
  ["@keyword.conditional"]  = { fg = p.magenta },
  ["@keyword.conditional.ternary"] = { fg = p.coral },  -- ?: is punctuation
  ["@keyword.coroutine"]    = { fg = p.magenta },
  ["@keyword.debug"]        = { fg = p.coral },
  ["@keyword.directive"]    = { fg = p.orange },
  ["@keyword.directive.define"] = { fg = p.orange },

  ["@type"]                 = { fg = p.green },
  ["@type.builtin"]         = { fg = p.green },
  ["@type.definition"]      = { fg = p.green },
  ["@type.qualifier"]       = { fg = p.magenta },

  ["@attribute"]            = { fg = p.orange, italic = true },
  ["@attribute.builtin"]    = { fg = p.orange, italic = true },
  ["@property"]             = { fg = p.aqua },

  ["@variable"]             = { fg = p.fg },
  -- this / self / super. Hot pink and italic, the same as the VS Code theme:
  -- it is a variable you did not declare, and it should not look like one you
  -- did.
  ["@variable.builtin"]     = { fg = p.hotpink, italic = true },
  ["@variable.parameter"]   = { fg = p.fg },
  ["@variable.parameter.builtin"] = { fg = p.hotpink, italic = true },
  ["@variable.member"]      = { fg = p.aqua },

  ["@label"]                = { fg = p.magenta },
  ["@module"]               = { fg = p.green },
  ["@module.builtin"]       = { fg = p.green },

  ["@tag"]                  = { fg = p.coral },
  ["@tag.builtin"]          = { fg = p.coral },
  ["@tag.attribute"]        = { fg = p.gold, italic = true },
  ["@tag.delimiter"]        = { fg = p.coral },

  ---------------------------------------------------------------------------
  -- Markup. Headings are coral, matching markup.heading in the VS Code theme.
  ---------------------------------------------------------------------------
  ["@markup.heading"]       = { fg = p.coral, bold = true },
  ["@markup.heading.1"]     = { fg = p.coral, bold = true },
  ["@markup.heading.2"]     = { fg = p.magenta, bold = true },
  ["@markup.heading.3"]     = { fg = p.cyan, bold = true },
  ["@markup.heading.4"]     = { fg = p.green, bold = true },
  ["@markup.heading.5"]     = { fg = p.gold, bold = true },
  ["@markup.heading.6"]     = { fg = p.orange, bold = true },

  ["@markup.strong"]        = { fg = p.gold, bold = true },
  ["@markup.italic"]        = { italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"]     = { underline = true },

  ["@markup.quote"]         = { fg = p.green, italic = true },
  ["@markup.math"]          = { fg = p.aqua },
  ["@markup.link"]          = { fg = p.cyan },
  ["@markup.link.label"]    = { fg = p.magenta },
  ["@markup.link.url"]      = { fg = p.cyan, underline = true },

  ["@markup.raw"]           = { fg = p.green },
  ["@markup.raw.block"]     = { fg = p.green },
  ["@markup.list"]          = { fg = p.coral },
  ["@markup.list.checked"]  = { fg = p.green },
  ["@markup.list.unchecked"]= { fg = p.faint },

  ["@diff.plus"]            = { fg = p.green, bg = wash.added },
  ["@diff.minus"]           = { fg = p.coral, bg = wash.removed },
  ["@diff.delta"]           = { fg = p.gold, bg = wash.changed },

  ["@none"]                 = {},

  ---------------------------------------------------------------------------
  -- LSP semantic tokens. These win over treesitter where a server provides
  -- them, so they have to agree with the block above or the same word changes
  -- colour the moment the server attaches.
  ---------------------------------------------------------------------------
  ["@lsp.type.class"]         = { link = "@type" },
  ["@lsp.type.comment"]       = {},   -- treesitter's is better; do not override
  ["@lsp.type.decorator"]     = { link = "@attribute" },
  ["@lsp.type.enum"]          = { link = "@type" },
  ["@lsp.type.enumMember"]    = { link = "@constant" },
  ["@lsp.type.function"]      = { link = "@function" },
  ["@lsp.type.interface"]     = { link = "@type" },
  ["@lsp.type.keyword"]       = { link = "@keyword" },
  ["@lsp.type.macro"]         = { link = "@function.macro" },
  ["@lsp.type.method"]        = { link = "@function.method" },
  ["@lsp.type.modifier"]      = { link = "@keyword.modifier" },
  ["@lsp.type.namespace"]     = { link = "@module" },
  ["@lsp.type.number"]        = { link = "@number" },
  ["@lsp.type.operator"]      = { link = "@operator" },
  ["@lsp.type.parameter"]     = { link = "@variable.parameter" },
  ["@lsp.type.property"]      = { link = "@property" },
  ["@lsp.type.regexp"]        = { link = "@string.regexp" },
  ["@lsp.type.string"]        = { link = "@string" },
  ["@lsp.type.struct"]        = { link = "@type" },
  ["@lsp.type.type"]          = { link = "@type" },
  ["@lsp.type.typeParameter"] = { fg = p.green_br },
  ["@lsp.type.variable"]      = { link = "@variable" },

  ["@lsp.mod.readonly"]       = { fg = p.orange },
  ["@lsp.mod.defaultLibrary"] = { fg = p.hotpink },
  ["@lsp.typemod.function.defaultLibrary"] = { fg = p.aqua },
  ["@lsp.typemod.variable.defaultLibrary"] = { fg = p.hotpink },

  ---------------------------------------------------------------------------
  -- Telescope. Three stacked panes, so they are separated by background
  -- rather than by border: prompt raised, results on the editor background,
  -- preview sunk.
  ---------------------------------------------------------------------------
  TelescopeNormal        = { fg = p.fg, bg = p.bg },
  TelescopeBorder        = { fg = p.border, bg = p.bg },
  TelescopeTitle         = { fg = p.faint },

  TelescopePromptNormal  = { fg = p.fg, bg = p.float },
  TelescopePromptBorder  = { fg = p.float, bg = p.float },
  TelescopePromptTitle   = { fg = p.bg, bg = p.hotpink, bold = true },
  TelescopePromptPrefix  = { fg = p.magenta, bg = p.float },
  TelescopePromptCounter = { fg = p.faint, bg = p.float },

  TelescopeResultsNormal = { fg = p.muted, bg = p.bg },
  TelescopeResultsBorder = { fg = p.bg, bg = p.bg },
  TelescopeResultsTitle  = { fg = p.bg, bg = p.bg },

  TelescopePreviewNormal = { fg = p.fg, bg = p.deep },
  TelescopePreviewBorder = { fg = p.deep, bg = p.deep },
  TelescopePreviewTitle  = { fg = p.bg, bg = p.green, bold = true },

  TelescopeSelection      = { bg = wash.pick, bold = true },
  TelescopeSelectionCaret = { fg = p.magenta, bg = wash.pick },
  TelescopeMultiSelection = { fg = p.orange, bg = wash.pick },
  TelescopeMultiIcon      = { fg = p.orange },
  -- The characters that actually matched what you typed. Cyan, the same as
  -- the suggest widget's highlightForeground in the VS Code theme.
  TelescopeMatching       = { fg = p.cyan, bold = true },

  ---------------------------------------------------------------------------
  -- neo-tree. The sidebar sits on the sunk background, the same ground
  -- Telescope's preview pane uses, so the editor stays the lit surface and
  -- the chrome around it recedes.
  ---------------------------------------------------------------------------
  NeoTreeNormal       = { fg = p.muted, bg = p.deep },
  NeoTreeNormalNC     = { fg = p.faint, bg = p.deep },
  NeoTreeEndOfBuffer  = { fg = p.deep, bg = p.deep },
  NeoTreeWinSeparator = { fg = p.line, bg = p.deep },
  NeoTreeCursorLine   = { bg = wash.pick },
  NeoTreeFloatBorder  = { fg = p.border, bg = p.float },
  NeoTreeFloatTitle   = { fg = p.magenta, bg = p.float, bold = true },
  NeoTreeTitleBar     = { fg = p.bg, bg = p.hotpink, bold = true },

  -- The project root is the one thing in the pane that is not a choice, so it
  -- gets the heading treatment rather than another file colour.
  NeoTreeRootName      = { fg = p.magenta, bold = true },
  NeoTreeDirectoryName = { fg = p.cyan },
  NeoTreeDirectoryIcon = { fg = p.cyan },
  NeoTreeFileName      = { fg = p.muted },
  NeoTreeFileIcon      = { fg = p.aqua },
  NeoTreeFileNameOpened= { fg = p.magenta, bold = true },
  NeoTreeSymbolicLinkTarget = { fg = p.aqua, italic = true },
  NeoTreeIndentMarker  = { fg = p.line },
  NeoTreeExpander      = { fg = p.faint },
  NeoTreeDimText       = { fg = p.faint },
  NeoTreeMessage       = { fg = p.faint, italic = true },
  NeoTreeModified      = { fg = p.gold },
  NeoTreeBufferNumber  = { fg = p.orange },
  NeoTreeFilterTerm    = { fg = p.cyan, bold = true },

  -- Git status, same three colours the diff groups use.
  NeoTreeGitAdded     = { fg = p.green },
  NeoTreeGitModified  = { fg = p.gold },
  NeoTreeGitDeleted   = { fg = p.coral },
  NeoTreeGitConflict  = { fg = p.coral, bold = true },
  NeoTreeGitUntracked = { fg = p.orange },
  NeoTreeGitIgnored   = { fg = p.faint },
  NeoTreeGitStaged    = { fg = p.green },
  NeoTreeGitUnstaged  = { fg = p.gold },

  NeoTreeTabActive            = { fg = p.magenta, bg = p.deep, bold = true },
  NeoTreeTabInactive          = { fg = p.faint, bg = p.shadow },
  NeoTreeTabSeparatorActive   = { fg = p.deep, bg = p.deep },
  NeoTreeTabSeparatorInactive = { fg = p.shadow, bg = p.shadow },

  ---------------------------------------------------------------------------
  -- lazy.nvim's own window
  ---------------------------------------------------------------------------
  LazyNormal       = { fg = p.fg, bg = p.float },
  LazyButton       = { fg = p.fg, bg = p.raised },
  LazyButtonActive = { fg = p.bg, bg = p.magenta, bold = true },
  LazyH1           = { fg = p.bg, bg = p.hotpink, bold = true },
  LazyH2           = { fg = p.magenta, bold = true },
  LazySpecial      = { fg = p.cyan },
  LazyCommit       = { fg = p.orange },
  LazyCommitIssue  = { fg = p.magenta },
  LazyCommitType   = { fg = p.magenta, bold = true },
  LazyCommitScope  = { fg = p.green, italic = true },
  LazyProgressDone = { fg = p.green, bold = true },
  LazyProgressTodo = { fg = p.line, bold = true },
  LazyProp         = { fg = p.aqua },
  LazyValue        = { fg = p.gold },
  LazyDir          = { fg = p.cyan },
  LazyUrl          = { fg = p.cyan, underline = true },
  LazyNoCond       = { fg = p.coral },
  LazyLocal        = { fg = p.orange },
  LazyDimmed       = { fg = p.faint },
  LazyReasonCmd     = { fg = p.cyan },
  LazyReasonEvent   = { fg = p.gold },
  LazyReasonFt      = { fg = p.green },
  LazyReasonImport  = { fg = p.fg },
  LazyReasonKeys    = { fg = p.magenta },
  LazyReasonPlugin  = { fg = p.orange },
  LazyReasonRuntime = { fg = p.dim },
  LazyReasonSource  = { fg = p.aqua },
  LazyReasonStart   = { fg = p.green_br },

  ---------------------------------------------------------------------------
  -- :checkhealth
  ---------------------------------------------------------------------------
  healthError   = { fg = p.coral },
  healthSuccess = { fg = p.green },
  healthWarning = { fg = p.gold },
}

for group, spec in pairs(hl) do
  vim.api.nvim_set_hl(0, group, spec)
end

-- :terminal, given the Ghostty palette verbatim so a shell inside nvim inside
-- Ghostty is the same sixteen colours the whole way down.
local ansi = {
  p.float, p.coral, p.green, p.gold, p.blue, p.magenta, p.cyan, p.fg,
  p.comment, p.coral_br, p.green_br, p.gold_br, p.blue_br, p.magenta_br, p.aqua, p.white,
}
for i, colour in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = colour
end
