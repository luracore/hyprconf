require("./config/env")
require("./config/startup")
require("./config/monitor")
-- monitores salvos pelo painel da barra (só existe depois de salvar algo lá)
local painel = io.open(os.getenv("HOME") .. "/hyprconf/hypr/config/monitor-painel.lua")
if painel then
  painel:close()
  require("./config/monitor-painel")
end
require("./config/appearance")
-- tema atual (gerado); sem ele, fica a cor de fundo padrão
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local current = io.open(config_home .. "/hypr/config/current.lua")
if current then
  current:close()
  require("./config/current")
end
require("./config/animations")
require("./config/layout")
require("./config/input")
require("./config/window-rules")
require("./config/binds")
