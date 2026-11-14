-- nvim-treesitter (branch main): instala os parsers; o destaque é do Neovim,
-- ligado por FileType.
return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local parsers = { "c", "lua", "vim", "vimdoc", "query" }

    require("nvim-treesitter").setup({})
    require("nvim-treesitter").install(parsers)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = parsers,
      callback = function()
        -- antes do parser terminar de instalar, o Neovim não tem o que ligar
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
