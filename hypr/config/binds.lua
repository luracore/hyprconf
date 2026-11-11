-- =========================================
-- APPLICATIONS
-- =========================================

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("hyprlauncher"))
hl.bind("SUPER + M", hl.dsp.exec_cmd(
  "quickshell --path $HOME/hyprconf/quickshell/wallpaper-picker/shell.qml"
))
hl.bind("SUPER + A", hl.dsp.exec_cmd("foot -e opencode"))


-- =========================================
-- SYSTEM
-- =========================================

hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprlock"))
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

for i = 1, 10 do
  local key = i % 10

  -- Switch workspace
  hl.bind(
    "SUPER + " .. key,
    hl.dsp.focus({ workspace = i })
  )

  -- Move window to workspace
  hl.bind(
    "SUPER + SHIFT + " .. key,
    hl.dsp.window.move({ workspace = i })
  )
end


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
-- Sem "repeating": cada acionamento do ddcutil leva ~0.5s e não convém
-- disparar vários processos concorrentes no barramento i2c.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("ddcutil setvcp 10 + 10"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("ddcutil setvcp 10 - 10"), { locked = true })
