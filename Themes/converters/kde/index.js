// Conversor dos apps KDE (KColorScheme): as cores dentro do kdeglobals.
//
//   build   escreve as seções [Colors:*] do ~/.config/kdeglobals
//
// A exceção ao modelo do "current": apps KDE só leem as cores de dentro do
// kdeglobals, sem como apontar para outro arquivo. Por isso este conversor
// edita o arquivo do usuário, mudando só as chaves de cor e preservando o
// resto. Só se o kdeglobals já existir (vem pronto em home/, com o nome do
// esquema e dos ícones; o install.sh copia se ainda não existir).

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { readIni, iniSet, writeIni } = require("../lib");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const KDEGLOBALS = path.join(CONFIG, "kdeglobals");

function build(c, { mix, parseHex }) {
    if (!fs.existsSync(KDEGLOBALS))
        return;

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

    const kde = readIni(KDEGLOBALS);
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
        for (const [key, value] of Object.entries(values))
            iniSet(kde, `Colors:${group}`, key, rgb(value));
    }
    writeIni(KDEGLOBALS, kde);
}

module.exports = { build };
