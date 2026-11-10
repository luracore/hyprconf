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
  --hl.exec_cmd("wayle panel start") vai ser removido
  hl.exec_cmd("quickshell --path $HOME/hyprconf/quickshell/bar")

  -- Idle manager
  hl.exec_cmd("hypridle")
end)
