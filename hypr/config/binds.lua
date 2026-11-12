-- =========================================
-- APPLICATIONS
-- =========================================

-- terminal, explorador e navegador: os padrões de ~/hyprconf/defaults.conf
local run = "$HOME/hyprconf/apps/hyprconf-run"

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(run .. " terminal"))
hl.bind("SUPER + E", hl.dsp.exec_cmd(run .. " files"))
hl.bind("SUPER + B", hl.dsp.exec_cmd(run .. " browser"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(
  "quickshell ipc --path $HOME/hyprconf/quickshell/launcher call launcher toggle"
))
hl.bind("SUPER + T", hl.dsp.exec_cmd(
  "quickshell --path $HOME/hyprconf/quickshell/wallpaper-picker/shell.qml"
))
hl.bind("SUPER + A", hl.dsp.exec_cmd(run .. " terminal -e opencode"))


-- =========================================
-- SYSTEM
-- =========================================

hl.bind("SUPER + P", hl.dsp.exec_cmd(
  "quickshell ipc --path $HOME/hyprconf/quickshell/bar call power toggle"
))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())


-- =========================================
-- SCREENSHOTS
-- =========================================

hl.bind("SUPER + S", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"))


-- =========================================
-- WINDOW NAVIGATION
-- =========================================

hl.bind("SUPER + H", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "down" }))


-- =========================================
-- WINDOW MANAGEMENT
-- =========================================

hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

hl.bind("SUPER + W", hl.dsp.window.close())

-- Toggle split
hl.bind("SUPER + D", hl.dsp.layout("togglesplit"))


-- =========================================
-- WINDOW STATES
-- =========================================

-- Maximized
hl.bind(
  "SUPER + F",
  hl.dsp.window.fullscreen({
    mode = "maximized",
    action = "toggle",
  })
)

-- Fullscreen
hl.bind(
  "SUPER + SHIFT + F",
  hl.dsp.window.fullscreen({
    mode = "fullscreen",
    action = "toggle",
  })
)


-- =========================================
-- WORKSPACES
-- =========================================

for i = 1, 9 do
  -- Switch workspace
  hl.bind(
    "SUPER + " .. i,
    hl.dsp.focus({ workspace = i })
  )

  -- Move window to workspace
  hl.bind(
    "SUPER + SHIFT + " .. i,
    hl.dsp.window.move({ workspace = i })
  )
end

-- O 0 é o workspace mágico: uma camada que abre e fecha por cima do
-- workspace atual, boa para deixar algo à mão (música, chat, terminal)
hl.bind("SUPER + 0",         hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "special:magic" }))


-- =========================================
-- TECLAS DE MÍDIA
-- =========================================

-- Volume / mute (PipeWire + WirePlumber)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Player (MPRIS, requer playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Brilho do monitor (DDC/CI, requer ddcutil)
-- Passa pela barra (módulo Brightness), que mostra o valor na hora e grava
-- no monitor com debounce, sem disparar vários ddcutil no barramento i2c.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("quickshell ipc --path $HOME/hyprconf/quickshell/bar call brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("quickshell ipc --path $HOME/hyprconf/quickshell/bar call brightness down"), { locked = true, repeating = true })
