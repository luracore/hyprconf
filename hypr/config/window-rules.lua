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

-- Blur atrás da tela de energia (quickshell/bar/modules/PowerMenu.qml)

hl.layer_rule({
  name = "blur-power-menu",
  match = {
    namespace = "^qs-power$",
  },
  blur = true,
})
