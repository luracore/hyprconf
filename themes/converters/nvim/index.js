// Qual cor vai em cada grupo de highlight fica em theme.lua; aqui só são
// preenchidos os marcadores dele.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "nvim/colors/current.lua");
const TEMPLATE = path.join(__dirname, "theme.lua");
const MARKERS = { colors: "--[[COLORS]] {}", name: '--[[NAME]] "current"' };

// só strings e listas de strings
function lua(value) {
    return Array.isArray(value)
        ? `{ ${value.map(v => JSON.stringify(v)).join(", ")} }`
        : JSON.stringify(value);
}

function mode(hex, parseHex) {
    const [r, g, b] = parseHex(hex);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 128 ? "light" : "dark";
}

function generate(c, { ansi, parseHex, name }) {
    const colors = Object.assign({}, c, { mode: mode(c.background, parseHex), ansi: ansi(c) });
    const table = "{\n"
        + Object.keys(colors).sort().map(k => `  ${k} = ${lua(colors[k])},`).join("\n")
        + "\n}";

    const template = fs.readFileSync(TEMPLATE, "utf8");
    for (const marker of Object.values(MARKERS)) {
        if (!template.includes(marker))
            throw new Error(`marcador ${marker} sumiu de ${TEMPLATE}`);
    }

    return "-- Gerado por hyprconf/themes/converters/nvim — não edite.\n"
        + "-- Para mudar as cores dos grupos, edite themes/converters/nvim/theme.lua.\n\n"
        + template
            .replace(MARKERS.colors, () => table)
            .replace(MARKERS.name, () => JSON.stringify(name));
}

module.exports = { target: TARGET, generate };
