local servers = require("lsp.servers")

return {
  "neovim/nvim-lspconfig",
  config = function()
    vim.diagnostic.config({
      virtual_text = false,
      virtual_lines = { current_line = true },
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = false,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "✘",
          [vim.diagnostic.severity.WARN] = "▲",
          [vim.diagnostic.severity.HINT] = "●",
          [vim.diagnostic.severity.INFO] = "●",
        },
      },
    })

    for name, opts in pairs(servers.mason) do
      vim.lsp.config(name, opts)
    end

    for name, opts in pairs(servers.system) do
      vim.lsp.config(name, opts)
      vim.lsp.enable(name)
    end
  end,
}
