// Só o que é comum aos conversores; o de um programa fica na pasta dele.

"use strict";

const fs = require("fs");
const path = require("path");
const { spawn, spawnSync } = require("child_process");

// Atômico: quem observa o arquivo nunca lê pela metade. O rename também
// substitui um link em vez de escrever através dele: current.ini ->
// tokyonight.ini vira um arquivo novo e o tokyonight.ini fica intacto.
function write(file, content) {
    const tmp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.tmp`);
    fs.writeFileSync(tmp, content);
    fs.renameSync(tmp, file);
}

function gsettings(...args) {
    return spawnSync("gsettings", args, { encoding: "utf8" });
}

function gsettingsGet(key) {
    return (gsettings("get", "org.gnome.desktop.interface", key).stdout || "")
        .trim().replace(/^'|'$/g, "");
}

// Apps GTK abertos só releem um tema quando o nome dele muda: troca para o
// Adwaita e volta. Precisa de uma pausa entre as trocas (senão os apps só
// veem o nome final), por isso roda em segundo plano.
function reloadGtk(key, name) {
    if (gsettingsGet(key) !== name)
        return;
    const schema = "org.gnome.desktop.interface";
    spawn("sh", ["-c", 'gsettings set "$1" "$2" Adwaita; sleep 0.2; gsettings set "$1" "$2" "$3"',
        "reload-gtk", schema, key, name], { detached: true, stdio: "ignore" }).unref();
}

module.exports = { write, gsettings, gsettingsGet, reloadGtk };
