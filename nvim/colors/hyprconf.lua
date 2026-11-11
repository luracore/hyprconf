-- Colorscheme gerado a partir do tema do hyprconf.
-- Paleta: ~/.local/state/hyprconf/theme/nvim.lua (Themes/apply-theme.js).

local path = vim.fn.expand("~/.local/state/hyprconf/theme/nvim.lua")
local ok, palette = pcall(dofile, path)

if not ok or type(palette) ~= "table" then
  vim.notify("hyprconf: paleta não encontrada (rode ~/hyprconf/Themes/apply-theme.js)",
    vim.log.levels.WARN)
  vim.cmd.colorscheme("habamax")
  return
end

local primary = palette.primary
palette.primary = nil

require("mini.base16").setup({ palette = palette, use_cterm = true })
vim.g.colors_name = "hyprconf"

-- Fundo transparente: deixa aparecer o fundo (e a transparência) do foot.
for _, group in ipairs({ "Normal", "NormalFloat", "NormalNC", "SignColumn", "LineNr", "FoldColumn" }) do
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  hl.bg = nil
  vim.api.nvim_set_hl(0, group, hl)
end

-- Destaques com a cor primária do tema.
if primary then
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = primary, bold = true })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = primary })
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = palette.base02 })
end
