// O colors.css fica na pasta do gtk-4.0, e não na do tema, porque é a única
// que os apps Flatpak enxergam; o tema (defaults/gtk) usa ele por um link.

"use strict";

const os = require("os");
const path = require("path");
const { reloadGtk } = require("../lib");

const NAME = "Hyprconf";
const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "gtk-4.0/colors.css");

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
    return "/* Gerado por hyprconf/themes/converters/gtk — não edite. */\n"
        + Object.entries(defines).map(([k, v]) => `@define-color ${k} ${v};\n`).join("");
}

function apply() {
    reloadGtk("gtk-theme", NAME);
}

module.exports = { target: TARGET, generate, apply };
