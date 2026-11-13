// Conversor dos ícones: o tema de ícones "Hyprconf".
//
//   build   refaz ~/.local/share/icons/Hyprconf (só se a pasta já existir)
//   apply   apps GTK abertos releem os ícones (se ainda forem os Hyprconf)
//
// Herda tudo do Papirus Dark e só troca as pastas azuis (o padrão do Papirus)
// por cópias recoloridas com a cor primária. A pasta vem pronta em home/ (um
// index.theme que só herda do Papirus) e o gsettings no dconf.ini; os outros
// toolkits apontam para os ícones nos arquivos prontos deles.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { write, reloadGtk } = require("../lib");

const NAME = "Hyprconf";
const ICON_THEME_DIR = path.join(os.homedir(), ".local/share/icons", NAME);
// a lista dos ícones azuis do Papirus (refeita quando o Papirus muda)
const CACHE = path.join(process.env.XDG_CACHE_HOME || path.join(os.homedir(), ".cache"),
    "hyprconf/papirus-blue.json");

const PAPIRUS = "/usr/share/icons/Papirus";
const SIZES = ["16x16", "22x22", "24x24", "32x32", "48x48", "64x64"];

// Os ícones azuis de cada tamanho: [nome, arquivo de verdade]. No Papirus,
// "folder-documents.svg" é um link para "folder-blue-documents.svg"; achar
// os azuis resolve as ~11 mil entradas das pastas places, o que é a parte
// lenta. A lista só muda com o Papirus, então fica guardada no cache.
function blueIcons() {
    const stamp = fs.statSync(path.join(PAPIRUS, "index.theme")).mtimeMs;
    try {
        const cached = JSON.parse(fs.readFileSync(CACHE, "utf8"));
        if (cached.stamp === stamp)
            return cached.sources;
    } catch {
        // sem cache (ou inválido): refaz
    }

    const sources = {};
    for (const size of SIZES) {
        const dir = fs.realpathSync(path.join(PAPIRUS, size, "places"));
        sources[size] = [];
        for (const name of fs.readdirSync(dir)) {
            let real;
            try {
                real = fs.realpathSync(path.join(dir, name));
            } catch (error) {
                continue;   // link quebrado
            }
            // folder-blue-*, user-blue-* (e não as folder-bluegrey-*)
            if (/^(folder|user)-blue[-.]/.test(path.basename(real)))
                sources[size].push([name, real]);
        }
    }
    write(CACHE, JSON.stringify({ stamp, sources }));
    return sources;
}

function build(c, { mix, warn }) {
    if (!fs.existsSync(ICON_THEME_DIR))
        return;
    if (!fs.existsSync(path.join(PAPIRUS, "index.theme"))) {
        warn("papirus-icon-theme não está instalado; os ícones não seguem o tema "
            + "(sudo pacman -S papirus-icon-theme)");
        return;
    }

    // as três cores da pasta azul do Papirus: frente, fundo e o símbolo
    const colors = {
        "#5294e2": c.primary,
        "#4877b1": mix(c.primary, "#000000", 0.2),
        "#1d344f": mix(c.primary, "#000000", 0.65),
    };
    const recolor = svg => svg.replace(/#(5294e2|4877b1|1d344f)\b/gi, hex => colors[hex.toLowerCase()]);

    const sources = blueIcons();

    // do zero, a cada troca: um tema velho não deixa ícones para trás
    for (const entry of fs.readdirSync(ICON_THEME_DIR))
        fs.rmSync(path.join(ICON_THEME_DIR, entry), { recursive: true, force: true });

    for (const size of SIZES) {
        const target = path.join(ICON_THEME_DIR, size, "places");
        fs.mkdirSync(target, { recursive: true });
        for (const [name, real] of sources[size])
            fs.writeFileSync(path.join(target, name), recolor(fs.readFileSync(real, "utf8")));
        // escala 2: os mesmos SVGs (como no Papirus)
        const n = size.split("x")[0];
        fs.symlinkSync(size, path.join(ICON_THEME_DIR, `${n}x${n}@2x`));
    }
    // tamanhos grandes usam os SVGs de 48 e 64 (como no Papirus)
    fs.symlinkSync("48x48", path.join(ICON_THEME_DIR, "96x96"));
    fs.symlinkSync("64x64", path.join(ICON_THEME_DIR, "128x128"));

    // as seções das pastas places copiadas do index.theme do Papirus
    const papirusIndex = fs.readFileSync(path.join(PAPIRUS, "index.theme"), "utf8");
    const dirs = [], scaled = [], sections = [];
    for (const size of [...SIZES, "96x96", "128x128"]) {
        const n = size.split("x")[0];
        for (const dir of [`${size}/places`, `${n}x${n}@2x/places`]) {
            const match = papirusIndex.match(new RegExp(`^\\[${dir.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\][^\\[]*`, "m"));
            if (!match)
                continue;
            (dir.includes("@2x") ? scaled : dirs).push(dir);
            sections.push(match[0].trim());
        }
    }
    write(path.join(ICON_THEME_DIR, "index.theme"),
        `[Icon Theme]\nName=${NAME}\nComment=Papirus Dark com as pastas na cor do tema (gerado por hyprconf)\n`
        + "Inherits=Papirus-Dark,hicolor\n"
        + `Directories=${dirs.join(",")}\nScaledDirectories=${scaled.join(",")}\n\n`
        + sections.join("\n\n") + "\n");
}

function apply() {
    reloadGtk("icon-theme", NAME);
}

module.exports = { build, apply };
