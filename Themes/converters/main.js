#!/usr/bin/env node
// Aplica o tema de Themes/current nos programas fora da barra.
//
// As cores são completadas pelo Themes/Colors.js, o mesmo arquivo que a
// barra e o seletor usam, e então vão para:
//
//   converters/<programa>/  uma pasta por programa (foot, gtk, icons, kde,
//                           nvim, qt); veja a seção "conversores" abaixo
//   fzf       ~/.local/share/hyprconf/theme/fzf.opts       (RepoStore)
//   hyprlock  ~/.local/share/hyprconf/theme/hyprlock.conf  (hypr/hyprlock.conf)
//
// Os conversores podem trazer arquivos prontos em home/ (espelho do $HOME) e
// gsettings em dconf.ini, que apontam o programa para o tema; o install.sh
// copia o que ainda não existir.
//
// Uso: main.js [--dry-run] [caminho/do/tema.json]   (padrão: Themes/current)
//      main.js --print <conversor> [tema.json]   só imprime a conversão
// Com --dry-run só gera os arquivos: não mexe nos terminais abertos nem no
// gsettings.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { write } = require("./lib");

const REPO = path.resolve(__dirname, "../..");
// cores do próprio hyprconf (fzf do RepoStore, hyprlock)
const THEME_DIR = path.join(os.homedir(), ".local/share/hyprconf/theme");
const DRY_RUN = process.argv.includes("--dry-run");

function warn(msg) {
    console.error(`converters: ${msg}`);
}

// Colors.js é uma biblioteca JS do QML (".pragma library", sem
// exports); aqui ele é carregado como função e devolve o que precisamos.
const Colors = (() => {
    const file = path.join(REPO, "Themes/Colors.js");
    const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+library\s*$/m, "");
    return new Function(`${source}\nreturn { resolve, mix, parseHex };`)();
})();

const { mix, parseHex } = Colors;

// ---- cores do terminal ----------------------------------------------------------

// As 16 cores ANSI a partir do tema (foot, :terminal do nvim...).
function ansi(c) {
    const bright = key => mix(c[key], "#FFFFFF", 0.12);
    return [
        c.surface, c.red, c.green, c.yellow,
        c.blue, c.magenta, c.cyan, mix(c.text, c.background, 0.2),
        c.muted, bright("red"), bright("green"), bright("yellow"),
        bright("blue"), bright("magenta"), bright("cyan"), mix(c.text, "#FFFFFF", 0.15),
    ];
}

// ---- do próprio hyprconf ---------------------------------------------------------

// Variáveis de cor para o hyprlock.conf (vale no próximo bloqueio).
function applyHyprlock(c) {
    const rgb = hex => `rgb(${hex.replace("#", "")})`;
    const vars = {
        background: c.background,
        surface: c.surface,
        text: c.text,
        muted: c.muted,
        primary: c.primary,
        success: c.success,
        warning: c.warning,
        error: c.error,
    };
    write(path.join(THEME_DIR, "hyprlock.conf"),
        "# Gerado por hyprconf/Themes/converters/main.js — não edite.\n"
        + Object.entries(vars).map(([k, v]) => `$${k} = ${rgb(v)}\n`).join(""));
}

// Cores do fzf do RepoStore.
function applyFzf(c) {
    // fundo transparente (-1): usa o do terminal, que já segue o tema
    const lines = [
        `--color=fg:${c.text},bg:-1,hl:${c.primary},fg+:${c.text},bg+:${c.surface},hl+:${c.primary}`,
        `--color=info:${c.muted},prompt:${c.primary},pointer:${c.primary},marker:${c.green},spinner:${c.primary}`,
        `--color=header:${c.muted},border:${c.outline},separator:${c.outline},scrollbar:${c.outline}`,
        `--color=label:${c.primary},query:${c.text},preview-bg:-1,gutter:-1`,
    ];
    write(path.join(THEME_DIR, "fzf.opts"), lines.join("\n") + "\n");
}

// ---- conversores --------------------------------------------------------------
// Cada pasta desta (converters/<programa>/) converte o tema para um programa.
// O index.js da pasta exporta um destes dois jeitos:
//
//   target               o "current" do programa: o arquivo que a config dele
//                        usa como tema ativo (só é escrito se a pasta já
//                        existir: o hyprconf não cria config para ninguém)
//   generate(c, tools)   devolve o conteúdo desse arquivo
//
//   build(c, tools)      para quando não é um arquivo só (uma pasta inteira,
//                        chaves dentro de um arquivo do usuário): o conversor
//                        escreve ele mesmo, e decide se deve
//
// e, nos dois casos:
//
//   apply(c, tools)      opcional: aplica ao vivo (fora do dry run)
//
// O hyprconf só preenche o current: a config do programa é que decide usar
// ele (veja Themes/README.md).
//
// Opcional, na pasta: home/ (arquivos prontos, espelho do $HOME; @HOME@ vira
// a pasta pessoal) e dconf.ini (gsettings), que o install.sh aplica só onde
// ainda não houver nada.
//
// tools: { mix, parseHex, ansi, name, warn }; o lib.js tem a escrita e o INI.
// O resto da pasta (templates etc.) é do conversor. Para conectar um programa
// novo, crie a pasta; para desconectar, apague.

function converters() {
    return fs.readdirSync(__dirname)
        .filter(name => fs.existsSync(path.join(__dirname, name, "index.js")))
        .sort()
        .map(name => [name, require(path.join(__dirname, name))]);
}

function runConverter(conv, colors, tools) {
    if (conv.build) {
        conv.build(colors, tools);
    } else {
        // o target fica na config do programa (o "current" dela); se a pasta
        // não existe, a config não reservou esse espaço: não é criada daqui
        if (!fs.existsSync(path.dirname(conv.target)))
            return;
        write(conv.target, conv.generate(colors, tools));
    }
    if (!DRY_RUN && conv.apply)
        conv.apply(colors, tools);
}

// ---- main --------------------------------------------------------------------

function main() {
    const args = process.argv.slice(2);
    const print = args.includes("--print") ? args[args.indexOf("--print") + 1] : null;
    const file = args.find((a, i) => !a.startsWith("--") && args[i - 1] !== "--print")
        || path.join(REPO, "Themes/current");
    let theme;
    try {
        theme = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (error) {
        warn(`não foi possível ler ${file}: ${error.message}`);
        return 1;
    }

    const colors = Colors.resolve(theme, null, warn);
    const tools = { mix, parseHex, ansi, warn, name: "current" };

    // --print: imprime a conversão de um programa, sem escrever nada
    // (ex.: gerar um tema pronto a partir de um tema)
    if (print) {
        const conv = converters().find(([name]) => name === print);
        if (!conv || !conv[1].generate) {
            warn(`conversor desconhecido ou sem um arquivo só para imprimir: ${print}`);
            return 1;
        }
        const name = path.basename(fs.realpathSync(file), ".json").toLowerCase();
        process.stdout.write(conv[1].generate(colors, Object.assign({}, tools, { name })));
        return 0;
    }

    let failed = false;
    const steps = [
        ["fzf", () => applyFzf(colors)],
        ["hyprlock", () => applyHyprlock(colors)],
        ...converters().map(([name, conv]) => [name, () => runConverter(conv, colors, tools)]),
    ];
    for (const [name, step] of steps) {
        try {
            step();
        } catch (error) {  // um programa com problema não trava os outros
            warn(`${name}: ${error.message}`);
            failed = true;
        }
    }
    return failed ? 1 : 0;
}

process.exitCode = main();
