require("./config/env")
require("./config/startup")
require("./config/monitor")
-- monitores salvos pelo painel da barra (só existe depois de salvar algo lá)
if io.open(os.getenv("HOME") .. "/hyprconf/hypr/config/monitor-painel.lua") then
  require("./config/monitor-painel")
end
require("./config/appearance")
require("./config/animations")
require("./config/layout")
require("./config/input")
require("./config/window-rules")
require("./config/binds")
