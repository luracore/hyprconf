// Os apps KDE só leem as cores de dentro do kdeglobals. Este fica numa pasta do
// XDG_CONFIG_DIRS (hypr/config/env.lua): um ~/.config/kdeglobals seu vale por
// cima dele.

"use strict";

const path = require("path");

const TARGET = path.resolve(__dirname, "../../../defaults/xdg/kdeglobals");

function generate(c, { mix, parseHex }) {
    const bg = c.background, fg = c.text, surface = c.surface, muted = c.muted;
    const base = mix(bg, "#000000", 0.12);
    const rgb = hex => parseHex(hex).join(",");

    const groups = {
        View: [base, mix(base, fg, 0.04)],
        Window: [bg, mix(bg, fg, 0.04)],
        Button: [surface, mix(surface, fg, 0.04)],
        Selection: [c.primary, mix(c.primary, bg, 0.2)],
        Tooltip: [surface, surface],
        Complementary: [mix(bg, "#000000", 0.3), bg],
        Header: [surface, surface],
    };

    let out = "[General]\nColorScheme=Hyprconf\n\n[Icons]\nTheme=Hyprconf\n";
    for (const [group, [normal, alternate]] of Object.entries(groups)) {
        const selection = group === "Selection";
        const fgNormal = selection ? c.onPrimary : fg;
        const values = {
            BackgroundNormal: normal,
            BackgroundAlternate: alternate,
            ForegroundNormal: fgNormal,
            ForegroundInactive: selection ? fgNormal : muted,
            ForegroundActive: selection ? fgNormal : c.primary,
            ForegroundLink: c.blue,
            ForegroundVisited: c.magenta,
            ForegroundNegative: c.error,
            ForegroundNeutral: c.warning,
            ForegroundPositive: c.success,
            DecorationFocus: c.primary,
            DecorationHover: c.primary,
        };
        out += `\n[Colors:${group}]\n`
            + Object.entries(values).map(([k, v]) => `${k}=${rgb(v)}\n`).join("");
    }
    return out;
}

module.exports = { target: TARGET, generate };
