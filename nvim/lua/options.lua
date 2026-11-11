-- Leader
vim.g.mapleader = " "

-- UI
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true

-- Window behavior
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Editing
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.virtualedit = "block"

-- Search
vim.opt.ignorecase = true
vim.opt.inccommand = "split"

-- System
vim.opt.clipboard = "unnamedplus"

-- Diagnostics (LSP)
vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Keymaps

-- Splits
vim.keymap.set("n", "<leader>s", ":vsplit<CR>", {
  desc = "Create new vertical split",
  silent = true,
})

vim.keymap.set("n", "<C-h>", "<C-w>h", {
  desc = "Move to left split",
  silent = true,
})

vim.keymap.set("n", "<C-j>", "<C-w>j", {
  desc = "Move to bottom split",
  silent = true,
})

vim.keymap.set("n", "<C-k>", "<C-w>k", {
  desc = "Move to top split",
  silent = true,
})

vim.keymap.set("n", "<C-l>", "<C-w>l", {
  desc = "Move to right split",
  silent = true,
})

-- Tabs
vim.keymap.set("n", "<leader><Tab>", ":tabnew<CR>", {
  desc = "Create new tab",
  silent = true,
})

vim.keymap.set("n", "<Tab>", "gt", {
  desc = "Go to next tab",
  silent = true,
})

vim.keymap.set("n", "<S-Tab>", "gT", {
  desc = "Go to previous tab",
  silent = true,
})

-- Terminal
vim.keymap.set("n", "<leader>t", ":terminal<CR>", {
  desc = "Open terminal",
  silent = true,
})

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
  desc = "Exit terminal mode",
  silent = true,
})

-- Format
vim.keymap.set("n", "<leader>=", function()
  local has_formatter = false

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if client:supports_method("textDocument/formatting") then
      has_formatter = true
      break
    end
  end

  if has_formatter then
    vim.lsp.buf.format()
  else
    vim.cmd("normal! gg=G")
  end
end, { desc = "Formatar arquivo" })
