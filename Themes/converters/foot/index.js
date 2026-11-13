// Conversor do foot: as cores do terminal a partir do tema.
//
//   target  ~/.config/foot/current.ini
//   apply   troca as cores dos terminais abertos na hora (OSC 4/10/11/12)
//
// O current.ini é o tema ativo da config do foot, que o inclui:
//   include=~/.config/foot/current.ini

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "foot/current.ini");

function generate(c, { ansi, mix }) {
    const hex = v => v.slice(1);
    const lines = ["# Gerado por hyprconf/Themes/converters/foot — não edite.", "[colors-dark]"];
    lines.push(`foreground=${hex(c.text)}`);
    lines.push(`background=${hex(c.background)}`);
    ansi(c).forEach((value, i) => lines.push(`${i < 8 ? "regular" : "bright"}${i % 8}=${hex(value)}`));
    lines.push(`selection-foreground=${hex(c.text)}`);
    lines.push(`selection-background=${hex(mix(c.background, c.primary, 0.35))}`);
    lines.push(`cursor=${hex(c.background)} ${hex(c.primary)}`);
    lines.push(`urls=${hex(c.info)}`);
    return `${lines.join("\n")}\n`;
}

// ptys dos shells filhos de um processo foot (inclui o foot --server)
function footPtys() {
    const procs = [];
    const footPids = new Set();

    for (const name of fs.readdirSync("/proc")) {
        if (!/^\d+$/.test(name))
            continue;
        let stat;
        try {
            stat = fs.readFileSync(`/proc/${name}/stat`, "utf8");
        } catch {
            continue;
        }
        const comm = stat.slice(stat.indexOf("(") + 1, stat.lastIndexOf(")"));
        const ppid = Number(stat.slice(stat.lastIndexOf(")") + 2).split(" ")[1]);
        procs.push({ pid: name, ppid });
        if (comm === "foot")
            footPids.add(Number(name));
    }

    const ptys = new Set();
    for (const { pid, ppid } of procs) {
        if (!footPids.has(ppid))
            continue;
        try {
            const tty = fs.readlinkSync(`/proc/${pid}/fd/0`);
            if (tty.startsWith("/dev/pts/"))
                ptys.add(tty);
        } catch {
            // processo sumiu ou não é nosso
        }
    }
    return ptys;
}

// Terminais abertos: manda as sequências OSC para o pty de cada shell.
function apply(c, { ansi, warn }) {
    let seq = ansi(c).map((v, i) => `\x1b]4;${i};${v}\x1b\\`).join("");
    seq += `\x1b]10;${c.text}\x1b\\\x1b]11;${c.background}\x1b\\\x1b]12;${c.primary}\x1b\\`;

    for (const tty of footPtys()) {
        try {
            fs.writeFileSync(tty, seq);
        } catch (error) {
            warn(`não foi possível atualizar ${tty}: ${error.message}`);
        }
    }
}

module.exports = { target: TARGET, generate, apply };
