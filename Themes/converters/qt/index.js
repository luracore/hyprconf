// Conversor do Qt (qt6ct): a paleta de cores do tema ativo.
//
//   target  ~/.config/qt6ct/colors/current.conf
//
// O qt6ct guarda os esquemas de cor nessa pasta. O qt6ct.conf que aponta para
// o current.conf vem pronto em home/ (o install.sh copia se ainda não
// existir); o QT_QPA_PLATFORMTHEME fica no hypr/config/env.lua. Apps Qt
// abertos só pegam o tema novo ao reabrir.

"use strict";

const os = require("os");
const path = require("path");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "qt6ct/colors/current.conf");

function generate(c, { mix }) {
    const bg = c.background, fg = c.text, surface = c.surface, muted = c.muted;
    const base = mix(bg, "#000000", 0.12);

    // Ordem de QPalette::ColorRole.
    const palette = (text, buttonText) => [
        text,                         // WindowText
        surface,                      // Button
        mix(surface, fg, 0.2),        // Light
        mix(surface, fg, 0.1),        // Midlight
        mix(bg, "#000000", 0.35),     // Dark
        mix(surface, bg, 0.5),        // Mid
        text,                         // Text
        "#FFFFFF",                    // BrightText
        buttonText,                   // ButtonText
        base,                         // Base
        bg,                           // Window
        "#000000",                    // Shadow
        c.primary,                    // Highlight
        c.onPrimary,                  // HighlightedText
        c.blue,                       // Link
        c.magenta,                    // LinkVisited
        mix(base, fg, 0.04),          // AlternateBase
        bg,                           // NoRole
        surface,                      // ToolTipBase
        fg,                           // ToolTipText
        muted,                        // PlaceholderText
        c.primary,                    // Accent
    ];

    const active = palette(fg, fg).join(", ");
    const disabled = palette(muted, muted).join(", ");
    // sem comentário de "gerado por": o qt6ct lê com o QSettings, que no INI
    // só garante ";" como comentário
    return "[ColorScheme]\n"
        + `active_colors=${active}\n`
        + `disabled_colors=${disabled}\n`
        + `inactive_colors=${active}\n`;
}

module.exports = { target: TARGET, generate };
