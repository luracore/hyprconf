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

hl.window_rule({
  name = "move-hyprland-run",
  match = {
    class = "hyprland-run",
  },
  move = "20 monitor_h-120",
  float = true,
})

-- RepoStore (apps/repostore/repostore): flutuando e centralizado

hl.window_rule({
  name = "package-app",
  match = {
    class = "^repostore$",
  },
  float = true,
  size = "1300 780",
  center = true,
})

-- Blur atrás da tela de energia, do lançador e do HyprSettings
-- (apps/quickbar/modules/PowerMenu.qml, apps/quicklauncher/Launcher.qml e
-- apps/hyprsettings/shell.qml)

hl.layer_rule({
  name = "blur-bar-overlays",
  match = {
    namespace = "^qs-(power|launcher|settings)$",
  },
  blur = true,
})
