hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + A", hl.dsp.layout("togglesplit"))

hl.bind(
  "SUPER + F",
  hl.dsp.window.fullscreen({
    mode = "maximized",
    action = "toggle",
  })
)

hl.bind(
  "SUPER + SHIFT + F",
  hl.dsp.window.fullscreen({
    mode = "fullscreen",
    action = "toggle",
  })
)
