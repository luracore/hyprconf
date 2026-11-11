-- Tema dinâmico: segue o tema do hyprconf (Themes/current).
--
-- O hyprconf/Themes/apply-theme.js gera a paleta base16 em
-- ~/.local/state/hyprconf/theme/nvim.lua; o colorscheme "hyprconf"
-- (colors/hyprconf.lua) aplica essa paleta com o mini.base16.
-- Quando o arquivo muda, todas as instâncias abertas recarregam sozinhas.
return {
  "echasnovski/mini.base16",
  lazy = false,
  priority = 1000,
  config = function()
    vim.cmd.colorscheme("hyprconf")

    local dir = vim.fn.expand("~/.local/state/hyprconf/theme")
    if vim.fn.isdirectory(dir) == 0 then
      return
    end

    local watcher = vim.uv.new_fs_event()
    local debounce = vim.uv.new_timer()

    watcher:start(dir, {}, function(err, filename)
      if err or filename ~= "nvim.lua" then
        return
      end

      -- o gerador escreve via rename; espera os eventos assentarem
      debounce:start(100, 0, vim.schedule_wrap(function()
        vim.cmd.colorscheme("hyprconf")
      end))
    end)

    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        watcher:stop()
        debounce:stop()
      end,
    })
  end,
}
