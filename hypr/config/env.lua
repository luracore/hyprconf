-- Apps Qt usam a paleta gerada pelo tema (themes/converters/main.js).
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Cursor gerado pelo tema (themes/converters/cursor); XCURSOR_* é o do XWayland.
hl.env("HYPRCURSOR_THEME", "Hyprconf-Cursor")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Hyprconf-Cursor")
hl.env("XCURSOR_SIZE", "24")

-- kdeglobals e gtk-3.0/settings.ini do hyprconf, abaixo dos seus em ~/.config.
local xdg = os.getenv("HOME") .. "/hyprconf/defaults/xdg"
local dirs = os.getenv("XDG_CONFIG_DIRS") or "/etc/xdg"
if not dirs:find(xdg, 1, true) then
  hl.env("XDG_CONFIG_DIRS", xdg .. ":" .. dirs)
end
