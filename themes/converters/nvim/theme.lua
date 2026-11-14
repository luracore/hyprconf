-- Lua normal: o index.js só troca os dois marcadores abaixo. Depois de
-- editar, rode themes/converters/main.js.
--
-- Cores disponíveis em `c` (as mesmas do themes/Colors.js):
--   neutras  background surface overlay outline muted text
--   paleta   red orange yellow green cyan blue magenta
--   papéis   primary secondary tertiary error warning success info
--   texto    onPrimary onError ... (cor legível por cima de cada uma)
--   ansi     as 16 cores do terminal (as mesmas do foot)
--   mode     "dark" ou "light", pela luminância do fundo

local c = --[[COLORS]] {}

-- Sem fundo próprio: aparece o fundo (e a transparência) do terminal.
local transparent = true

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = c.mode
vim.g.colors_name = --[[NAME]] "current"

local function mix(a, b, t)
  local function rgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  end
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  local function m(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return string.format("#%02X%02X%02X", m(r1, r2), m(g1, g2), m(b1, b2))
end

local function hl(name, opts)
  vim.api.nvim_set_hl(0, name, opts)
end

local bg = not transparent and c.background or nil
local float_bg = not transparent and c.surface or nil
local cursorline = mix(c.background, c.text, 0.06)

hl("Normal", { fg = c.text, bg = bg })
hl("NormalNC", { link = "Normal" })
hl("NormalFloat", { fg = c.text, bg = float_bg })
hl("FloatBorder", { fg = c.primary, bg = float_bg })
hl("FloatTitle", { fg = c.primary, bg = float_bg, bold = true })
hl("Cursor", { fg = c.background, bg = c.primary })
hl("CursorLine", { bg = cursorline })
hl("CursorColumn", { link = "CursorLine" })
hl("ColorColumn", { bg = c.surface })
hl("CursorLineNr", { fg = c.primary, bold = true })
hl("LineNr", { fg = c.outline })
hl("SignColumn", { bg = bg })
hl("FoldColumn", { fg = c.outline, bg = bg })
hl("Folded", { fg = c.muted, bg = c.surface })
hl("Visual", { bg = mix(c.background, c.primary, 0.3) })
hl("VisualNOS", { link = "Visual" })
hl("Search", { fg = c.background, bg = c.yellow })
hl("IncSearch", { fg = c.background, bg = c.orange })
hl("CurSearch", { link = "IncSearch" })
hl("Substitute", { fg = c.background, bg = c.red })
hl("MatchParen", { fg = c.primary, bg = c.overlay, bold = true })
hl("Pmenu", { fg = c.text, bg = c.surface })
hl("PmenuSel", { fg = c.onPrimary, bg = c.primary })
hl("PmenuKind", { fg = c.magenta, bg = c.surface })
hl("PmenuExtra", { fg = c.muted, bg = c.surface })
hl("PmenuSbar", { bg = c.surface })
hl("PmenuThumb", { bg = c.outline })
hl("StatusLine", { fg = c.text, bg = c.surface })
hl("StatusLineNC", { fg = c.muted, bg = c.surface })
hl("TabLine", { fg = c.muted, bg = c.surface })
hl("TabLineSel", { fg = c.onPrimary, bg = c.primary, bold = true })
hl("TabLineFill", { bg = bg })
hl("WinBar", { fg = c.text, bold = true })
hl("WinBarNC", { fg = c.muted })
hl("WinSeparator", { fg = c.overlay })
hl("NonText", { fg = c.overlay })
hl("Whitespace", { fg = c.overlay })
hl("EndOfBuffer", { fg = c.overlay })
hl("SpecialKey", { fg = c.outline })
hl("Directory", { fg = c.blue })
hl("Title", { fg = c.primary, bold = true })
hl("Question", { fg = c.green })
hl("MoreMsg", { fg = c.green })
hl("ModeMsg", { fg = c.text, bold = true })
hl("ErrorMsg", { fg = c.error })
hl("WarningMsg", { fg = c.warning })
hl("WildMenu", { link = "PmenuSel" })
hl("QuickFixLine", { bg = cursorline, bold = true })
hl("Conceal", { fg = c.muted })
hl("SpellBad", { sp = c.error, undercurl = true })
hl("SpellCap", { sp = c.warning, undercurl = true })
hl("SpellRare", { sp = c.magenta, undercurl = true })
hl("SpellLocal", { sp = c.cyan, undercurl = true })

hl("Comment", { fg = c.muted, italic = true })
hl("Constant", { fg = c.orange })
hl("String", { fg = c.green })
hl("Character", { link = "String" })
hl("Number", { fg = c.orange })
hl("Boolean", { fg = c.orange })
hl("Float", { link = "Number" })
hl("Identifier", { fg = c.text })
hl("Function", { fg = c.blue })
hl("Statement", { fg = c.magenta })
hl("Conditional", { link = "Statement" })
hl("Repeat", { link = "Statement" })
hl("Label", { link = "Statement" })
hl("Keyword", { link = "Statement" })
hl("Exception", { link = "Statement" })
hl("Operator", { fg = c.cyan })
hl("PreProc", { fg = c.yellow })
hl("Include", { fg = c.magenta })
hl("Define", { link = "PreProc" })
hl("Macro", { link = "PreProc" })
hl("Type", { fg = c.yellow })
hl("StorageClass", { link = "Type" })
hl("Structure", { link = "Type" })
hl("Typedef", { link = "Type" })
hl("Special", { fg = c.cyan })
hl("SpecialChar", { link = "Special" })
hl("Tag", { fg = c.blue })
hl("Delimiter", { fg = mix(c.text, c.muted, 0.5) })
hl("SpecialComment", { fg = c.muted, bold = true })
hl("Debug", { fg = c.red })
hl("Underlined", { underline = true })
hl("Error", { fg = c.error })
hl("Todo", { fg = c.onWarning, bg = c.warning, bold = true })

hl("Added", { fg = c.green })
hl("Changed", { fg = c.yellow })
hl("Removed", { fg = c.red })
hl("DiffAdd", { bg = mix(c.background, c.green, 0.2) })
hl("DiffChange", { bg = mix(c.background, c.yellow, 0.12) })
hl("DiffDelete", { fg = c.red, bg = mix(c.background, c.red, 0.2) })
hl("DiffText", { bg = mix(c.background, c.yellow, 0.3) })
hl("diffAdded", { link = "Added" })
hl("diffChanged", { link = "Changed" })
hl("diffRemoved", { link = "Removed" })
hl("GitSignsAdd", { link = "Added" })
hl("GitSignsChange", { link = "Changed" })
hl("GitSignsDelete", { link = "Removed" })

hl("@variable", { fg = c.text })
hl("@variable.builtin", { fg = c.red })
hl("@variable.parameter", { fg = c.text, italic = true })
hl("@variable.member", { fg = c.cyan })
hl("@property", { fg = c.cyan })
hl("@constant", { link = "Constant" })
hl("@constant.builtin", { fg = c.orange })
hl("@module", { fg = c.yellow })
hl("@label", { link = "Label" })
hl("@string", { link = "String" })
hl("@string.escape", { fg = c.cyan })
hl("@string.regexp", { fg = c.cyan })
hl("@string.special", { fg = c.cyan })
hl("@character", { link = "Character" })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@type", { link = "Type" })
hl("@type.builtin", { fg = c.yellow })
hl("@attribute", { fg = c.cyan })
hl("@function", { link = "Function" })
hl("@function.builtin", { fg = c.blue })
hl("@function.method", { link = "Function" })
hl("@constructor", { fg = c.yellow })
hl("@keyword", { link = "Keyword" })
hl("@keyword.import", { link = "Include" })
hl("@operator", { link = "Operator" })
hl("@punctuation.delimiter", { link = "Delimiter" })
hl("@punctuation.bracket", { link = "Delimiter" })
hl("@punctuation.special", { fg = c.cyan })
hl("@comment", { link = "Comment" })
hl("@comment.todo", { link = "Todo" })
hl("@comment.error", { fg = c.onError, bg = c.error, bold = true })
hl("@comment.warning", { link = "Todo" })
hl("@comment.note", { fg = c.onInfo, bg = c.info, bold = true })
hl("@tag", { link = "Tag" })
hl("@tag.attribute", { fg = c.cyan })
hl("@tag.delimiter", { link = "Delimiter" })
hl("@markup.heading", { fg = c.primary, bold = true })
hl("@markup.strong", { bold = true })
hl("@markup.italic", { italic = true })
hl("@markup.strikethrough", { strikethrough = true })
hl("@markup.underline", { underline = true })
hl("@markup.link", { fg = c.blue, underline = true })
hl("@markup.link.url", { fg = c.blue, underline = true })
hl("@markup.raw", { fg = c.green })
hl("@markup.list", { fg = c.magenta })
hl("@markup.quote", { fg = c.muted, italic = true })
hl("@diff.plus", { link = "Added" })
hl("@diff.minus", { link = "Removed" })
hl("@diff.delta", { link = "Changed" })

hl("@lsp.type.parameter", { link = "@variable.parameter" })
hl("@lsp.type.property", { link = "@property" })
hl("@lsp.type.namespace", { link = "@module" })
hl("@lsp.type.enumMember", { link = "@constant" })

for name, color in pairs({
  Error = c.error,
  Warn = c.warning,
  Info = c.info,
  Hint = c.tertiary,
  Ok = c.success,
}) do
  hl("Diagnostic" .. name, { fg = color })
  hl("DiagnosticVirtualText" .. name, { fg = color, bg = mix(c.background, color, 0.1) })
  hl("DiagnosticUnderline" .. name, { sp = color, undercurl = true })
end
hl("DiagnosticUnnecessary", { fg = c.muted })
hl("LspReferenceText", { bg = c.overlay })
hl("LspReferenceRead", { bg = c.overlay })
hl("LspReferenceWrite", { bg = c.overlay })
hl("LspInlayHint", { fg = c.muted, italic = true })
hl("LspSignatureActiveParameter", { fg = c.primary, bold = true, underline = true })

hl("TelescopeBorder", { link = "FloatBorder" })
hl("TelescopeTitle", { fg = c.primary, bold = true })
hl("TelescopeSelection", { link = "CursorLine" })
hl("TelescopeMatching", { fg = c.primary, bold = true })
hl("TelescopePromptPrefix", { fg = c.primary })

hl("BlinkCmpMenuBorder", { link = "FloatBorder" })
hl("BlinkCmpDocBorder", { link = "FloatBorder" })
hl("BlinkCmpLabelMatch", { fg = c.primary, bold = true })

hl("MiniFilesBorder", { link = "FloatBorder" })
hl("MiniFilesTitleFocused", { fg = c.primary, bold = true })

for i, color in ipairs(c.ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
