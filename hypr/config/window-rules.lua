-- Fix XWayland Drags

hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },
  no_focus = true,
})

-- Move Hyprland Run

hl.window_rule({
  name = "move-hyprland-run",
  match = {
    class = "hyprland-run",
  },
  move = "20 monitor_h-120",
  float = true,
})

-- Apps de pacotes (apps/hyprconf-*): flutuando e centralizados

hl.window_rule({
  name = "package-apps",
  match = {
    class = "^hyprconf-(pacman|aur|remover)$",
  },
  float = true,
  size = "1100 760",
  center = true,
})

-- Blur atrás da tela de energia e do lançador
-- (quickshell/bar/modules/PowerMenu.qml e quickshell/launcher/Launcher.qml)

hl.layer_rule({
  name = "blur-bar-overlays",
  match = {
    namespace = "^qs-(power|launcher)$",
  },
  blur = true,
})
