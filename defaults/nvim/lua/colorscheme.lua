-- colors/current.lua (fora do git) é um link para um tema daqui ou o arquivo
-- que o hyprconf escreve.

local uv = vim.uv
local colors_dir = vim.fn.stdpath("config") .. "/colors"
local current = colors_dir .. "/current.lua"

local function apply()
  if not pcall(vim.cmd.colorscheme, "current") then
    vim.notify("colors/current.lua não existe; para usar o tema pronto:\n"
      .. "ln -sfn tokyonight.lua ~/.config/nvim/colors/current.lua", vim.log.levels.WARN)
  end
end

-- Observa as pastas, e não o arquivo, porque quem escreve o tema costuma
-- escrever num temporário e renomear.

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
