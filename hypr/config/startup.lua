hl.on("hyprland.start", function()
  -- Polkit
  hl.exec_cmd("systemctl --user start hyprpolkitagent")

  -- Wallpaper daemon
  hl.exec_cmd("awww-daemon")

  -- Wallpaper
  hl.exec_cmd([[
    sleep 2
    if [ -e "$HOME/hyprconf/Wallpapers/current" ]; then
      awww img "$HOME/hyprconf/Wallpapers/current" --resize crop --transition-type none
    else
      awww img --color 000000
    fi
  ]])

  -- Panel
  hl.exec_cmd("quickshell --path $HOME/hyprconf/apps/quickbar")

  -- App launcher (fica rodando; SUPER + SPACE abre por IPC)
  hl.exec_cmd("quickshell --path $HOME/hyprconf/apps/quicklauncher")

  -- Idle manager
  hl.exec_cmd("hypridle")
end)
