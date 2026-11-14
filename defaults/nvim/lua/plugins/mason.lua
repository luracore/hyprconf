local servers = require("lsp.servers")
local mason_servers = vim.tbl_keys(servers.mason)

return {
  "mason-org/mason.nvim",
  dependencies = {
    "mason-org/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    require("mason").setup()

    require("mason-lspconfig").setup({
      ensure_installed = mason_servers,
      automatic_enable = mason_servers,
    })
  end,
}
