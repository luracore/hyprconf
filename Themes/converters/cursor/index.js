// Conversor do cursor: o tema "Hyprconf-Cursor".
//
//   build   refaz ~/.local/share/icons/Hyprconf-Cursor (só se a pasta já existir)
//   apply   o Hyprland e os apps GTK abertos trocam de cursor na hora
//
// Os SVGs de svg/ usam cores marcadoras: #00FF00 (corpo) vira background,
// #0000FF (contorno) vira primary e #FF0000 (símbolos) vira text. Um
// <g id="spin" data-cx data-cy> gira em FRAMES quadros.
//
// A pasta leva o hyprcursor (SVG: Hyprland e apps Wayland) e o Xcursor (PNG:
// XWayland e GTK3). Os dois só procuram temas nas pastas de ícones.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const { write, reloadGtk } = require("../lib");

const NAME = "Hyprconf-Cursor";
const THEME_DIR = path.join(os.homedir(), ".local/share/icons", NAME);
const SVG_DIR = path.join(__dirname, "svg");

const VIEWBOX = 32;                     // os SVGs são 32x32
const XCURSOR_SIZES = [24, 32, 48, 64]; // 24 e 32 em escala 1, 48 e 64 em 2
const FRAMES = 12;                      // quadros por volta das animações
const DELAY = 60;                       // ms por quadro

// Cada SVG de svg/: o hotspot (no 32x32) e os outros nomes que ele atende,
// os do protocolo cursor-shape (os que o Hyprland e os apps Wayland pedem) e
// os antigos do X11 (inclusive os hashes que o Qt e o GTK3 procuram).
const CURSORS = {
    "default": [[5, 3], ["left_ptr", "arrow", "top_left_arrow", "left_arrow"]],
    "context-menu": [[5, 3], []],
    "help": [[5, 3], ["question_arrow", "whats_this", "left_ptr_help",
        "5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b458ad60b"]],
    "copy": [[5, 3], ["dnd-copy",
        "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872"]],
    "alias": [[5, 3], ["link", "dnd-link",
        "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f"]],
    "progress": [[5, 3], ["left_ptr_watch", "half-busy",
        "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd",
        "3ecb610c1bf2410f44200f48c40d3599"]],
    "wait": [[16, 16], ["watch"]],
    "pointer": [[12.75, 3], ["hand", "hand1", "hand2", "pointing_hand",
        "9d800788f1b08800ae810202380a0822", "e29285e634086352946a0e7090d73106"]],
    "grab": [[15.5, 16], ["openhand", "5aca4d189052212118709018842178c0"]],
    "grabbing": [[15.5, 18], ["closedhand", "fcf21c00b30f7e3f83fe0dfd12e71cff"]],
    "text": [[16, 16], ["xterm", "ibeam"]],
    "vertical-text": [[16, 16], []],
    "crosshair": [[16, 16], ["cross", "tcross", "cross_reverse", "diamond_cross", "cell", "plus"]],
    "move": [[16, 16], ["fleur", "all-scroll", "size_all", "dnd-move",
        "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"]],
    "not-allowed": [[16, 16], ["no-drop", "forbidden", "crossed_circle", "circle",
        "dnd-no-drop", "03b6e0fcb3499374a867c041f52298f0"]],
    "ew-resize": [[16, 16], ["e-resize", "w-resize", "col-resize", "h_double_arrow",
        "sb_h_double_arrow", "size_hor", "left_side", "right_side", "split_h",
        "14fef782d02440884392942c11205230", "028006030e0e7ebffc7f7070c0600140"]],
    "ns-resize": [[16, 16], ["n-resize", "s-resize", "row-resize", "v_double_arrow",
        "sb_v_double_arrow", "size_ver", "top_side", "bottom_side", "split_v",
        "2870a09082c103050810ffdffffe0204", "00008160000006810000408080010102"]],
    "nwse-resize": [[16, 16], ["nw-resize", "se-resize", "size_fdiag", "bd_double_arrow",
        "top_left_corner", "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000"]],
    "nesw-resize": [[16, 16], ["ne-resize", "sw-resize", "size_bdiag", "fd_double_arrow",
        "top_right_corner", "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000"]],
    "zoom-in": [[13, 13], []],
    "zoom-out": [[13, 13], []],
};

function has(cmd) {
    return spawnSync("sh", ["-c", 'command -v "$1"', "sh", cmd]).status === 0;
}

function run(cmd, args, opts) {
    const r = spawnSync(cmd, args, Object.assign({ encoding: "utf8" }, opts));
    if (r.status !== 0)
        throw new Error(`${cmd} falhou: ${(r.stderr || r.error || "").toString().trim()}`);
    return r;
}

// Os quadros de um cursor (um só, se não for animado), já com as cores.
function frames(svg) {
    const spin = /<g id="spin" data-cx="([\d.]+)" data-cy="([\d.]+)">/.exec(svg);
    if (!spin)
        return [svg];
    return Array.from({ length: FRAMES }, (_, i) => svg.replace(spin[0],
        `${spin[0].slice(0, -1)} transform="rotate(${(360 / FRAMES) * i} ${spin[1]} ${spin[2]})">`));
}

// hyprcursor: uma pasta por cursor (meta.hl + SVGs), empacotada pelo
// hyprcursor-util em hyprcursors/<nome>.hlc.
function buildHyprcursor(work, cursors) {
    const src = path.join(work, "hyprcursor-src");
    for (const { name, hot, aliases, svgs } of cursors) {
        const dir = path.join(src, "hyprcursors", name);
        fs.mkdirSync(dir, { recursive: true });
        const meta = [
            "resize_algorithm = bilinear",
            `hotspot_x = ${hot[0] / VIEWBOX}`,
            `hotspot_y = ${hot[1] / VIEWBOX}`,
        ];
        if (aliases.length)
            meta.push(`define_override = ${aliases.join(";")}`);
        svgs.forEach((svg, i) => {
            const file = `${name}-${String(i).padStart(2, "0")}.svg`;
            fs.writeFileSync(path.join(dir, file), svg);
            meta.push(`define_size = 0, ${file}` + (svgs.length > 1 ? `, ${DELAY}` : ""));
        });
        fs.writeFileSync(path.join(dir, "meta.hl"), meta.join("\n") + "\n");
    }
    fs.writeFileSync(path.join(src, "manifest.hl"),
        `name = ${NAME}\ndescription = Cursor nas cores do tema (gerado por hyprconf)\n`
        + "version = 1\ncursors_directory = hyprcursors\n");

    const out = path.join(work, "hyprcursor-out");
    fs.mkdirSync(out);
    run("hyprcursor-util", ["--create", src, "--output", out]);
    return path.join(out, `theme_${NAME}`);
}

// Xcursor: cada quadro vira PNG em cada tamanho (rsvg-convert, em paralelo)
// e o xcursorgen junta tudo em cursors/<nome>; os outros nomes são links.
function buildXcursor(work, cursors) {
    const png = path.join(work, "png");
    const out = path.join(work, "cursors");
    fs.mkdirSync(png);
    fs.mkdirSync(out);

    const jobs = [];
    const configs = [];
    for (const { name, hot, svgs } of cursors) {
        const lines = [];
        svgs.forEach((svg, i) => {
            const svgFile = path.join(png, `${name}-${i}.svg`);
            fs.writeFileSync(svgFile, svg);
            for (const size of XCURSOR_SIZES) {
                const file = path.join(png, `${name}-${i}-${size}.png`);
                const scale = size / VIEWBOX;
                jobs.push(String(size), svgFile, file);
                lines.push(`${size} ${Math.round(hot[0] * scale)} ${Math.round(hot[1] * scale)} ${file}`
                    + (svgs.length > 1 ? ` ${DELAY}` : ""));
            }
        });
        configs.push([name, lines]);
    }

    run("xargs", ["-0", "-n", "3", "-P", String(os.cpus().length || 4),
        "sh", "-c", 'rsvg-convert -w "$0" -h "$0" -o "$2" "$1"'], { input: jobs.join("\0") });

    for (const [name, lines] of configs) {
        const config = path.join(png, `${name}.cfg`);
        fs.writeFileSync(config, lines.join("\n") + "\n");
        run("xcursorgen", [config, path.join(out, name)]);
    }
    for (const { name, aliases } of cursors)
        for (const alias of aliases)
            fs.symlinkSync(name, path.join(out, alias));
    return out;
}

function build(c, { warn }) {
    if (!fs.existsSync(THEME_DIR))
        return;
    if (!has("hyprcursor-util") || !has("rsvg-convert")) {
        warn("cursor: faltam o hyprcursor-util (hyprcursor) ou o rsvg-convert (librsvg); "
            + "o cursor não segue o tema");
        return;
    }

    const colors = { "#00ff00": c.background, "#0000ff": c.primary, "#ff0000": c.text };
    const cursors = Object.entries(CURSORS).map(([name, [hot, aliases]]) => {
        const svg = fs.readFileSync(path.join(SVG_DIR, `${name}.svg`), "utf8")
            .replace(/#(00ff00|0000ff|ff0000)\b/gi, hex => colors[hex.toLowerCase()]);
        return { name, hot, aliases, svgs: frames(svg) };
    });

    // monta tudo numa pasta ao lado e só no fim troca pelo tema antigo: o
    // cursor nunca fica pela metade, e um tema velho não deixa sobras
    const work = path.join(path.dirname(THEME_DIR), `.${NAME}.build`);
    fs.rmSync(work, { recursive: true, force: true });
    fs.mkdirSync(work);
    try {
        const theme = path.join(work, "theme");
        fs.renameSync(buildHyprcursor(work, cursors), theme);

        if (has("xcursorgen"))
            fs.renameSync(buildXcursor(work, cursors), path.join(theme, "cursors"));
        else
            warn("cursor: xcursorgen não está instalado; os apps XWayland e GTK3 ficam "
                + "com o cursor padrão (sudo pacman -S xorg-xcursorgen)");

        // Inherits: o que faltar aqui vem do Adwaita, e não do "X" do X11
        write(path.join(theme, "index.theme"),
            `[Icon Theme]\nName=${NAME}\nComment=Cursor nas cores do tema (gerado por hyprconf)\n`
            + "Inherits=Adwaita\n");

        for (const entry of fs.readdirSync(THEME_DIR))
            fs.rmSync(path.join(THEME_DIR, entry), { recursive: true, force: true });
        for (const entry of fs.readdirSync(theme))
            fs.renameSync(path.join(theme, entry), path.join(THEME_DIR, entry));
    } finally {
        fs.rmSync(work, { recursive: true, force: true });
    }
}

function apply() {
    // o Hyprland só relê o tema quando recebe o setcursor (o mesmo nome basta)
    if (process.env.HYPRLAND_INSTANCE_SIGNATURE && has("hyprctl")) {
        const size = process.env.HYPRCURSOR_SIZE || process.env.XCURSOR_SIZE || "24";
        spawnSync("hyprctl", ["setcursor", NAME, size], { stdio: "ignore" });
    }
    reloadGtk("cursor-theme", NAME);
}

module.exports = { build, apply };
