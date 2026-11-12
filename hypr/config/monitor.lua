-- Regra padrão: vale para qualquer monitor sem regra própria. As mudanças
-- feitas no painel de monitores da barra (clique no brilho) ficam em
-- monitor-painel.lua e valem por cima desta.
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = "1",
})
