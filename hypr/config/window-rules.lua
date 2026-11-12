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

-- App Pacotes (apps/hyprconf-pacotes): flutuando e centralizado

hl.window_rule({
  name = "package-app",
  match = {
    class = "^hyprconf-pacotes$",
  },
  float = true,
  size = "1300 780",
  center = true,
})

-- Blur atrás da tela de energia, do lançador e das Configurações
-- (quickshell/bar/modules/PowerMenu.qml e quickshell/launcher/Launcher.qml)

hl.layer_rule({
  name = "blur-bar-overlays",
  match = {
    namespace = "^qs-(power|launcher|settings)$",
  },
  blur = true,
})
