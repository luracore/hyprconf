// Funções compartilhadas pelo main.js e pelos conversores. Só o genérico:
// o que é de um programa fica na pasta do conversor dele.

"use strict";

const fs = require("fs");
const path = require("path");
const { spawn, spawnSync } = require("child_process");

// ---- escrita -----------------------------------------------------------------

// Escreve de forma atômica (quem observa o arquivo nunca lê pela metade).
// O rename também substitui um link no lugar do arquivo, em vez de escrever
// através dele: um current.ini -> tokyonight.ini vira um arquivo novo, e o
// tokyonight.ini continua intacto.
function write(file, content) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const tmp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.tmp`);
    fs.writeFileSync(tmp, content);
    fs.renameSync(tmp, file);
}

// ---- INI ---------------------------------------------------------------------
// Leitura/escrita simples de INI (qt6ct.conf, kdeglobals, settings.ini):
// muda só as chaves pedidas e preserva o resto, inclusive comentários.

function readIni(file) {
    const ini = { head: [], sections: new Map() };
    if (!fs.existsSync(file))
        return ini;

    let lines = ini.head;
    for (const raw of fs.readFileSync(file, "utf8").split("\n")) {
        const line = raw.trim();
        if (line === "")
            continue;

        const header = /^\[(.+)\]$/.exec(line);
        if (header) {
            if (!ini.sections.has(header[1]))
                ini.sections.set(header[1], []);
            lines = ini.sections.get(header[1]);
            continue;
        }

        const eq = line.indexOf("=");
        if (line.startsWith("#") || line.startsWith(";") || eq < 0)
            lines.push({ comment: line });
        else
            lines.push({ key: line.slice(0, eq).trim(), value: line.slice(eq + 1).trim() });
    }
    return ini;
}

function iniSet(ini, section, key, value) {
    if (!ini.sections.has(section))
        ini.sections.set(section, []);
    const entries = ini.sections.get(section);
    const entry = entries.find(e => e.key === key);
    if (entry)
        entry.value = value;
    else
        entries.push({ key, value });
}

function writeIni(file, ini) {
    const line = e => (e.comment !== undefined ? e.comment : `${e.key}=${e.value}`);
    let out = ini.head.map(e => `${line(e)}\n`).join("");
    if (out)
        out += "\n";
    for (const [name, entries] of ini.sections)
        out += `[${name}]\n${entries.map(e => `${line(e)}\n`).join("")}\n`;
    write(file, out);
}

// ---- gsettings ---------------------------------------------------------------

function gsettings(...args) {
    return spawnSync("gsettings", args, { encoding: "utf8" });
}

function gsettingsGet(key) {
    return (gsettings("get", "org.gnome.desktop.interface", key).stdout || "")
        .trim().replace(/^'|'$/g, "");
}

// Apps GTK abertos só releem um tema quando o nome dele muda: se `key` aponta
// para o tema `name`, troca para o Adwaita e volta. Se o usuário escolheu
// outro tema, não mexe.
//
// Roda em segundo plano (a troca precisa de uma pausa entre as duas mudanças,
// senão os apps só veem o nome final e não releem): quem aplica o tema não
// espera, e o tema e os ícones recarregam ao mesmo tempo.
function reloadGtk(key, name) {
    if (gsettingsGet(key) !== name)
        return;
    const schema = "org.gnome.desktop.interface";
    spawn("sh", ["-c", 'gsettings set "$1" "$2" Adwaita; sleep 0.2; gsettings set "$1" "$2" "$3"',
        "reload-gtk", schema, key, name], { detached: true, stdio: "ignore" }).unref();
}

module.exports = { write, readIni, iniSet, writeIni, gsettings, gsettingsGet, reloadGtk };
