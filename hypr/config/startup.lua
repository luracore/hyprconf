hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user start hyprpolkitagent")

  hl.exec_cmd("awww-daemon")

  hl.exec_cmd([[
    until awww query >/dev/null 2>&1; do sleep 0.05; done
    if [ -e "$HOME/hyprconf/wallpapers/current" ]; then
      awww img "$HOME/hyprconf/wallpapers/current" --resize crop --transition-type none
    else
      awww img --color 000000
    fi
  ]])

  hl.exec_cmd("quickshell --path $HOME/hyprconf/apps/quickbar")

  -- o lançador fica rodando; SUPER + SPACE abre por IPC
  hl.exec_cmd("quickshell --path $HOME/hyprconf/apps/quicklauncher")

  hl.exec_cmd("hypridle")
end)
