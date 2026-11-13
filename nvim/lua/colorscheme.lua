-- Colorscheme: colors/current.lua, o tema ativo (fora do git). É um link
-- para um tema daqui, criado uma vez depois do clone:
--   ln -sfn tokyonight.lua ~/.config/nvim/colors/current.lua
-- ou um arquivo escrito por outro programa (o hyprconf escreve nele o tema
-- do sistema). Sem ele, o Neovim fica com as cores padrão e avisa.
--
-- Quando o link muda, ou o arquivo para onde ele aponta muda, todas as
-- instâncias abertas recarregam sozinhas.

local uv = vim.uv
local colors_dir = vim.fn.stdpath("config") .. "/colors"
local current = colors_dir .. "/current.lua"

local function apply()
  if not pcall(vim.cmd.colorscheme, "current") then
    vim.notify("colors/current.lua não existe; para usar o tema pronto:\n"
      .. "ln -sfn tokyonight.lua ~/.config/nvim/colors/current.lua", vim.log.levels.WARN)
  end
end

-- ---- recarregar quando mudar ------------------------------------------------
-- Dois observadores: a pasta colors/ (o link foi trocado) e a pasta do arquivo
-- para onde o link aponta (o arquivo foi reescrito). Quem escreve o tema
-- costuma escrever num temporário e renomear, então observar o arquivo em si
-- não funciona: observamos a pasta e filtramos pelo nome.

local watchers = {}
local debounce = uv.new_timer()
local reload

local function watch(dir, name)
  local watcher = uv.new_fs_event()
  local ok = watcher:start(dir, {}, function(err, filename)
    if err or filename ~= name then
      return
    end
    debounce:start(100, 0, vim.schedule_wrap(reload))
  end)
  if ok then
    table.insert(watchers, watcher)
  else
    watcher:close()
  end
end

local function stop_watchers()
  for _, watcher in ipairs(watchers) do
    watcher:stop()
    watcher:close()
  end
  watchers = {}
end

local function start_watchers()
  stop_watchers()
  watch(colors_dir, "current.lua")

  -- o link pode apontar para outra pasta (e mudar de pasta ao ser trocado)
  local target = uv.fs_realpath(current)
  if target and vim.fs.dirname(target) ~= colors_dir then
    watch(vim.fs.dirname(target), vim.fs.basename(target))
  end
end

reload = function()
  apply()
  start_watchers()
end

reload()

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    stop_watchers()
    debounce:stop()
  end,
})
