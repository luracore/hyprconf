// Conversor do Neovim: gera um colorscheme completo a partir do tema.
//
// O mapeamento (qual cor vai em cada grupo de highlight) fica em theme.lua,
// escrito em Lua. Aqui só são preenchidas as cores do tema e o nome.
//
//   target  ~/.config/nvim/colors/current.lua
//
// O current.lua é o colorscheme ativo da config do Neovim
// (":colorscheme current").

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "nvim/colors/current.lua");
const TEMPLATE = path.join(__dirname, "theme.lua");
const MARKERS = { colors: "--[[COLORS]] {}", name: '--[[NAME]] "current"' };

// valor JS -> literal Lua (só strings e listas de strings)
function lua(value) {
    return Array.isArray(value)
        ? `{ ${value.map(v => JSON.stringify(v)).join(", ")} }`
        : JSON.stringify(value);
}

// fundo claro ou escuro (vim.o.background), pela luminância do fundo
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

    return "-- Gerado por hyprconf/Themes/converters/nvim — não edite.\n"
        + "-- Para mudar as cores dos grupos, edite Themes/converters/nvim/theme.lua.\n\n"
        + template
            .replace(MARKERS.colors, () => table)
            .replace(MARKERS.name, () => JSON.stringify(name));
}

module.exports = { target: TARGET, generate };
