#!/usr/bin/env node
// Uso: main.js [--dry-run] [tema.json]          (padrão: themes/current)
//      main.js --print <conversor> [tema.json]   só imprime a conversão
// Com --dry-run só gera os arquivos: não mexe nos programas abertos nem no
// gsettings.

"use strict";

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { write } = require("./lib");

const REPO = path.resolve(__dirname, "../..");
const DRY_RUN = process.argv.includes("--dry-run");

function warn(msg) {
    console.error(`converters: ${msg}`);
}

// Colors.js é uma biblioteca do QML (".pragma library", sem exports): é
// carregado como corpo de função.
const Colors = (() => {
    const file = path.join(REPO, "themes/Colors.js");
    const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+library\s*$/m, "");
    return new Function(`${source}\nreturn { resolve, mix, parseHex };`)();
})();

const { mix, parseHex } = Colors;

function ansi(c) {
    const bright = key => mix(c[key], "#FFFFFF", 0.12);
    return [
        c.surface, c.red, c.green, c.yellow,
        c.blue, c.magenta, c.cyan, mix(c.text, c.background, 0.2),
        c.muted, bright("red"), bright("green"), bright("yellow"),
        bright("blue"), bright("magenta"), bright("cyan"), mix(c.text, "#FFFFFF", 0.15),
    ];
}

// Conversores: cada converters/<programa>/index.js exporta
//   target + generate(c, tools)  o arquivo que a config do programa usa como
//                                tema ativo (a pasta dele tem de existir) e o
//                                conteúdo dele
//   ou build(c, tools)           quando não é um arquivo só: escreve sozinho
//   apply(c, tools)              opcional, fora do --dry-run: aplica ao vivo;
//                                pode vir sem target nem build
// tools: { mix, parseHex, ansi, name, warn }. Um dconf.ini opcional na pasta
// tem os gsettings que o install.sh escreve e o uninstall.sh reseta.
// Criar a pasta conecta o programa; apagar desconecta.

function converters() {
    return fs.readdirSync(__dirname)
        .filter(name => fs.existsSync(path.join(__dirname, name, "index.js")))
        .sort()
        .map(name => [name, require(path.join(__dirname, name))])
        // os que montam pastas inteiras por último: os outros aplicam sem esperar
        .sort(([, a], [, b]) => !!a.build - !!b.build);
}

function runConverter(conv, colors, tools) {
    if (conv.build) {
        conv.build(colors, tools);
    } else if (conv.target) {
        write(conv.target, conv.generate(colors, tools));
    }
    if (!DRY_RUN && conv.apply)
        conv.apply(colors, tools);
}

// Os Quickshell abertos não percebem a troca do symlink themes/current: cada
// um é avisado pelo IPC, em segundo plano.
function reloadQuickshell() {
    const script = `quickshell list --all 2>/dev/null | awk '/^Instance/ { sub(":", "", $2); print $2 }' |
        while read -r id; do quickshell ipc --id "$id" call theme reloadTheme 2>/dev/null; done`;
    spawn("sh", ["-c", script], { detached: true, stdio: "ignore" }).unref();
}

function main() {
    const args = process.argv.slice(2);
    const print = args.includes("--print") ? args[args.indexOf("--print") + 1] : null;
    const file = args.find((a, i) => !a.startsWith("--") && args[i - 1] !== "--print")
        || path.join(REPO, "themes/current");
    let theme;
    try {
        theme = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (error) {
        warn(`não foi possível ler ${file}: ${error.message}`);
        return 1;
    }

    const colors = Colors.resolve(theme, null, warn);
    const tools = { mix, parseHex, ansi, warn, name: "current" };

    // --print serve para gerar os temas prontos (ex.: tokyonight.ini)
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
    if (!DRY_RUN)
        reloadQuickshell();
    const steps = converters().map(([name, conv]) => [name, () => runConverter(conv, colors, tools)]);
    for (const [name, step] of steps) {
        try {
            step();
        } catch (error) {
            warn(`${name}: ${error.message}`);
            failed = true;
        }
    }
    return failed ? 1 : 0;
}

process.exitCode = main();
