hl.bind("SUPER + M", hl.dsp.exec_cmd("quickshell --path $HOME/hyprconf/quickshell/wallpaper-picker/shell.qml"))

hl.bind("SUPER + W", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("hyprlauncher"))

hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exit())

hl.bind("SUPER + S", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"))
