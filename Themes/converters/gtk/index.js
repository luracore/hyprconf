// Conversor do GTK: as cores do tema "Hyprconf".
//
//   target  ~/.local/share/themes/Hyprconf/colors.css
//   apply   apps GTK3 abertos releem o tema (se ele ainda for o Hyprconf)
//
// O resto vem pronto em home/ (o install.sh copia o que ainda não existir):
// o tema em si (index.theme e o gtk.css de cada versão, por cima do adw-gtk3)
// e o que aponta o GTK para ele (settings.ini; o gtk-4.0/gtk.css dos apps
// libadwaita). O gsettings, que não é arquivo, está no dconf.ini.

"use strict";

const os = require("os");
const path = require("path");
const { reloadGtk } = require("../lib");

const NAME = "Hyprconf";
const TARGET = path.join(os.homedir(), ".local/share/themes", NAME, "colors.css");

function generate(c, { mix }) {
    const bg = c.background, fg = c.text, surface = c.surface;
    const defines = {
        accent_color: c.primary,
        accent_bg_color: c.primary,
        accent_fg_color: c.onPrimary,
        destructive_color: c.error,
        destructive_bg_color: c.error,
        destructive_fg_color: c.onError,
        success_color: c.success,
        success_bg_color: c.success,
        success_fg_color: c.onSuccess,
        warning_color: c.warning,
        warning_bg_color: c.warning,
        warning_fg_color: c.onWarning,
        error_color: c.error,
        error_bg_color: c.error,
        error_fg_color: c.onError,
        window_bg_color: bg,
        window_fg_color: fg,
        view_bg_color: mix(bg, "#000000", 0.12),
        view_fg_color: fg,
        headerbar_bg_color: surface,
        headerbar_fg_color: fg,
        headerbar_border_color: fg,
        headerbar_backdrop_color: bg,
        headerbar_shade_color: "rgba(0, 0, 0, 0.36)",
        sidebar_bg_color: surface,
        sidebar_fg_color: fg,
        sidebar_backdrop_color: bg,
        sidebar_shade_color: "rgba(0, 0, 0, 0.25)",
        secondary_sidebar_bg_color: mix(surface, bg, 0.5),
        secondary_sidebar_fg_color: fg,
        card_bg_color: mix(bg, fg, 0.05),
        card_fg_color: fg,
        card_shade_color: "rgba(0, 0, 0, 0.36)",
        dialog_bg_color: surface,
        dialog_fg_color: fg,
        popover_bg_color: surface,
        popover_fg_color: fg,
        popover_shade_color: "rgba(0, 0, 0, 0.25)",
        thumbnail_bg_color: surface,
        thumbnail_fg_color: fg,
        shade_color: "rgba(0, 0, 0, 0.36)",
        scrollbar_outline_color: "rgba(0, 0, 0, 0.5)",
    };
    return "/* Gerado por hyprconf/Themes/converters/gtk — não edite. */\n"
        + Object.entries(defines).map(([k, v]) => `@define-color ${k} ${v};\n`).join("");
}

function apply() {
    reloadGtk("gtk-theme", NAME);
}

module.exports = { target: TARGET, generate, apply };
