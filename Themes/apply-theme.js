#!/usr/bin/env node
// Aplica o tema de Themes/current nos programas fora da barra.
//
// As cores são resolvidas pelo Themes/ThemeColors.js, o mesmo arquivo que a
// barra e o seletor usam, e então são escritas para:
//
//   foot     ~/.local/state/hyprconf/theme/foot.ini   (incluído pelo foot.ini)
//            + troca as cores dos terminais abertos na hora (OSC 4/10/11/12)
//   neovim   ~/.local/state/hyprconf/theme/nvim.lua   (o nvim observa e recarrega)
//   gtk      ~/.local/share/themes/Hyprconf           (tema baseado no adw-gtk3)
//            + ~/.config/gtk-4.0/gtk.css para apps libadwaita
//   fzf      ~/.local/state/hyprconf/theme/fzf.opts   (apps de pacotes)
//   qt       ~/.local/state/hyprconf/theme/qt6ct.conf (paleta do qt6ct)
//            + cores do KDE em ~/.config/kdeglobals (apps KDE)
//
// Uso: apply-theme.js [caminho/do/tema.json]   (padrão: Themes/current)
// Com APPLY_THEME_DRY_RUN=1 só gera os arquivos: não mexe nos terminais
// abertos nem no gsettings.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const REPO = path.resolve(__dirname, "..");
const HOME = os.homedir();
const CONFIG = process.env.XDG_CONFIG_HOME || path.join(HOME, ".config");
const STATE = path.join(HOME, ".local/state/hyprconf/theme");
const GTK_THEME_NAME = "Hyprconf";
const GTK_THEME_DIR = path.join(HOME, ".local/share/themes", GTK_THEME_NAME);
const ADW_GTK3 = "/usr/share/themes/adw-gtk3-dark";
const DRY_RUN = process.env.APPLY_THEME_DRY_RUN === "1";

function warn(msg) {
    console.error(`apply-theme: ${msg}`);
}

// ThemeColors.js é uma biblioteca JS do QML (".pragma library", sem
// exports); aqui ele é carregado como função e devolve o que precisamos.
const ThemeColors = (() => {
    const file = path.join(__dirname, "ThemeColors.js");
    const source = fs.readFileSync(file, "utf8").replace(/^\s*\.pragma\s+library\s*$/m, "");
    return new Function(`${source}\nreturn { resolve, mix, parseHex };`)();
})();

const { mix, parseHex } = ThemeColors;

function rgbCsv(value) {
    return parseHex(value).join(",");
}

// ---- escrita -----------------------------------------------------------------

// Escreve de forma atômica (quem observa o arquivo nunca lê pela metade).
function write(file, content) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const tmp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.tmp`);
    fs.writeFileSync(tmp, content);
    fs.renameSync(tmp, file);
}

// Garante que `line` está no topo de um arquivo do usuário, sem apagar nada.
function ensureLine(file, line) {
    const current = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
    if (current.split("\n").includes(line))
        return;
    write(file, `${line}\n${current}`);
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

function iniSetDefault(ini, section, key, value) {
    const entries = ini.sections.get(section) || [];
    if (!entries.some(e => e.key === key))
        iniSet(ini, section, key, value);
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

// ---- foot --------------------------------------------------------------------

function ansi(c) {
    const bright = key => mix(c[key], "#FFFFFF", 0.12);
    return [
        c.surface, c.red, c.green, c.yellow,
        c.blue, c.magenta, c.cyan, mix(c.text, c.background, 0.2),
        c.muted, bright("red"), bright("green"), bright("yellow"),
        bright("blue"), bright("magenta"), bright("cyan"), mix(c.text, "#FFFFFF", 0.15),
    ];
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

function applyFoot(c) {
    const colors = ansi(c);
    const hex = v => v.slice(1);
    const lines = ["# Gerado por hyprconf/Themes/apply-theme.js — não edite.", "[colors-dark]"];
    lines.push(`foreground=${hex(c.text)}`);
    lines.push(`background=${hex(c.background)}`);
    colors.forEach((value, i) => lines.push(`${i < 8 ? "regular" : "bright"}${i % 8}=${hex(value)}`));
    lines.push(`selection-foreground=${hex(c.text)}`);
    lines.push(`selection-background=${hex(mix(c.background, c.primary, 0.35))}`);
    lines.push(`cursor=${hex(c.background)} ${hex(c.primary)}`);
    lines.push(`urls=${hex(c.info)}`);
    write(path.join(STATE, "foot.ini"), `${lines.join("\n")}\n`);

    if (DRY_RUN)
        return;

    // Terminais abertos: manda as sequências OSC para o pty de cada shell.
    let seq = colors.map((v, i) => `\x1b]4;${i};${v}\x1b\\`).join("");
    seq += `\x1b]10;${c.text}\x1b\\\x1b]11;${c.background}\x1b\\\x1b]12;${c.primary}\x1b\\`;

    for (const tty of footPtys()) {
        try {
            fs.writeFileSync(tty, seq);
        } catch (error) {
            warn(`não foi possível atualizar ${tty}: ${error.message}`);
        }
    }
}

// ---- fzf (apps de pacotes) -----------------------------------------------------

function applyFzf(c) {
    // fundo transparente (-1): usa o do terminal, que já segue o tema
    const lines = [
        `--color=fg:${c.text},bg:-1,hl:${c.primary},fg+:${c.text},bg+:${c.surface},hl+:${c.primary}`,
        `--color=info:${c.muted},prompt:${c.primary},pointer:${c.primary},marker:${c.green},spinner:${c.primary}`,
        `--color=header:${c.muted},border:${c.outline},separator:${c.outline},scrollbar:${c.outline}`,
        `--color=label:${c.primary},query:${c.text},preview-bg:-1,gutter:-1`,
    ];
    write(path.join(STATE, "fzf.opts"), lines.join("\n") + "\n");
}

// ---- neovim ------------------------------------------------------------------

function applyNvim(c) {
    const base16 = {
        base00: c.background,
        base01: c.surface,
        base02: c.overlay,
        base03: c.muted,
        base04: mix(c.muted, c.text, 0.5),
        base05: c.text,
        base06: mix(c.text, "#FFFFFF", 0.1),
        base07: mix(c.text, "#FFFFFF", 0.2),
        base08: c.red,
        base09: c.orange,
        base0A: c.yellow,
        base0B: c.green,
        base0C: c.cyan,
        base0D: c.blue,
        base0E: c.magenta,
        base0F: mix(c.red, c.background, 0.35),
    };
    const body = Object.entries(base16).map(([k, v]) => `  ${k} = "${v}",`).join("\n");
    write(path.join(STATE, "nvim.lua"),
        "-- Gerado por hyprconf/Themes/apply-theme.js — não edite.\n"
        + `return {\n${body}\n  primary = "${c.primary}",\n}\n`);
}

// ---- gtk ---------------------------------------------------------------------

function gsettings(...args) {
    return spawnSync("gsettings", args, { encoding: "utf8" });
}

function applyGtk(c) {
    const bg = c.background, fg = c.text, surface = c.surface;
    const defines = {
        accent_color: c.primary,
        accent_bg_color: c.primary,
        accent_fg_color: c.onPrimary,
        destructive_color: c.error,
        destructive_bg_color: c.error,
        destructive_fg_color: c.onError,
        success_color: c.success,
        success_bg_color: c.success,
        success_fg_color: c.onSuccess,
        warning_color: c.warning,
        warning_bg_color: c.warning,
        warning_fg_color: c.onWarning,
        error_color: c.error,
        error_bg_color: c.error,
        error_fg_color: c.onError,
        window_bg_color: bg,
        window_fg_color: fg,
        view_bg_color: mix(bg, "#000000", 0.12),
        view_fg_color: fg,
        headerbar_bg_color: surface,
        headerbar_fg_color: fg,
        headerbar_border_color: fg,
        headerbar_backdrop_color: bg,
        headerbar_shade_color: "rgba(0, 0, 0, 0.36)",
        sidebar_bg_color: surface,
        sidebar_fg_color: fg,
        sidebar_backdrop_color: bg,
        sidebar_shade_color: "rgba(0, 0, 0, 0.25)",
        secondary_sidebar_bg_color: mix(surface, bg, 0.5),
        secondary_sidebar_fg_color: fg,
        card_bg_color: mix(bg, fg, 0.05),
        card_fg_color: fg,
        card_shade_color: "rgba(0, 0, 0, 0.36)",
        dialog_bg_color: surface,
        dialog_fg_color: fg,
        popover_bg_color: surface,
        popover_fg_color: fg,
        popover_shade_color: "rgba(0, 0, 0, 0.25)",
        thumbnail_bg_color: surface,
        thumbnail_fg_color: fg,
        shade_color: "rgba(0, 0, 0, 0.36)",
        scrollbar_outline_color: "rgba(0, 0, 0, 0.5)",
    };
    write(path.join(GTK_THEME_DIR, "colors.css"),
        "/* Gerado por hyprconf/Themes/apply-theme.js — não edite. */\n"
        + Object.entries(defines).map(([k, v]) => `@define-color ${k} ${v};\n`).join(""));

    // Apps libadwaita (GTK4) ignoram o tema e leem ~/.config/gtk-4.0/gtk.css.
    ensureLine(path.join(CONFIG, "gtk-4.0/gtk.css"), `@import url("file://${GTK_THEME_DIR}/colors.css");`);

    // O tema GTK3 é construído por cima do adw-gtk3; sem ele, ativar o tema
    // deixaria os apps GTK3 sem estilo nenhum.
    if (!fs.existsSync(ADW_GTK3)) {
        warn("adw-gtk-theme não está instalado; apps GTK3 não vão seguir o tema "
            + "(sudo pacman -S adw-gtk-theme)");
        return;
    }

    write(path.join(GTK_THEME_DIR, "index.theme"),
        `[Desktop Entry]\nType=X-GNOME-Metatheme\nName=${GTK_THEME_NAME}\n`
        + "Comment=Gerado por hyprconf\n\n[X-GNOME-Metatheme]\n"
        + `GtkTheme=${GTK_THEME_NAME}\n`);

    for (const version of ["gtk-3.0", "gtk-4.0"]) {
        write(path.join(GTK_THEME_DIR, version, "gtk.css"),
            `@import url("file://${ADW_GTK3}/${version}/gtk.css");\n`
            + `@import url("file://${GTK_THEME_DIR}/colors.css");\n`);
    }

    const settingsFile = path.join(CONFIG, "gtk-3.0/settings.ini");
    const settings = readIni(settingsFile);
    iniSet(settings, "Settings", "gtk-theme-name", GTK_THEME_NAME);
    iniSet(settings, "Settings", "gtk-application-prefer-dark-theme", "1");
    writeIni(settingsFile, settings);

    if (DRY_RUN)
        return;

    // Apps GTK3 abertos recarregam o tema quando o nome muda: troca para o
    // Adwaita e volta, para eles relerem o CSS novo.
    gsettings("set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark");
    const current = (gsettings("get", "org.gnome.desktop.interface", "gtk-theme").stdout || "")
        .trim().replace(/^'|'$/g, "");
    if (current === GTK_THEME_NAME) {
        gsettings("set", "org.gnome.desktop.interface", "gtk-theme", "Adwaita");
        spawnSync("sleep", ["0.2"]);
    }
    gsettings("set", "org.gnome.desktop.interface", "gtk-theme", GTK_THEME_NAME);
}

// ---- qt ----------------------------------------------------------------------

function applyQt(c) {
    const bg = c.background, fg = c.text, surface = c.surface, muted = c.muted;
    const base = mix(bg, "#000000", 0.12);

    // Ordem de QPalette::ColorRole.
    const palette = (text, buttonText) => [
        text,                         // WindowText
        surface,                      // Button
        mix(surface, fg, 0.2),        // Light
        mix(surface, fg, 0.1),        // Midlight
        mix(bg, "#000000", 0.35),     // Dark
        mix(surface, bg, 0.5),        // Mid
        text,                         // Text
        "#FFFFFF",                    // BrightText
        buttonText,                   // ButtonText
        base,                         // Base
        bg,                           // Window
        "#000000",                    // Shadow
        c.primary,                    // Highlight
        c.onPrimary,                  // HighlightedText
        c.blue,                       // Link
        c.magenta,                    // LinkVisited
        mix(base, fg, 0.04),          // AlternateBase
        bg,                           // NoRole
        surface,                      // ToolTipBase
        fg,                           // ToolTipText
        muted,                        // PlaceholderText
        c.primary,                    // Accent
    ];

    const active = palette(fg, fg).join(", ");
    const disabled = palette(muted, muted).join(", ");
    write(path.join(STATE, "qt6ct.conf"),
        "[ColorScheme]\n"
        + `active_colors=${active}\n`
        + `disabled_colors=${disabled}\n`
        + `inactive_colors=${active}\n`);

    // Configuração do qt6ct: só as chaves de cor/estilo; o resto é preservado.
    const confFile = path.join(CONFIG, "qt6ct/qt6ct.conf");
    const conf = readIni(confFile);
    iniSet(conf, "Appearance", "color_scheme_path", path.join(STATE, "qt6ct.conf"));
    iniSet(conf, "Appearance", "custom_palette", "true");
    iniSetDefault(conf, "Appearance", "style", "Fusion");
    iniSetDefault(conf, "Appearance", "icon_theme", "breeze-dark");
    writeIni(confFile, conf);

    // Cores KDE (KColorScheme), usadas por apps KDE.
    const groups = {
        View: [base, mix(base, fg, 0.04)],
        Window: [bg, mix(bg, fg, 0.04)],
        Button: [surface, mix(surface, fg, 0.04)],
        Selection: [c.primary, mix(c.primary, bg, 0.2)],
        Tooltip: [surface, surface],
        Complementary: [mix(bg, "#000000", 0.3), bg],
        Header: [surface, surface],
    };
    const kdeFile = path.join(CONFIG, "kdeglobals");
    const kde = readIni(kdeFile);
    for (const [group, [normal, alternate]] of Object.entries(groups)) {
        const section = `Colors:${group}`;
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
            iniSet(kde, section, key, rgbCsv(value));
    }
    iniSet(kde, "General", "ColorScheme", GTK_THEME_NAME);
    writeIni(kdeFile, kde);
}

// ---- main --------------------------------------------------------------------

function main() {
    const file = process.argv[2] || path.join(REPO, "Themes/current");
    let theme;
    try {
        theme = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (error) {
        warn(`não foi possível ler ${file}: ${error.message}`);
        return 1;
    }

    const colors = ThemeColors.resolve(theme, null, warn);
    let failed = false;
    for (const [name, step] of [["foot", applyFoot], ["fzf", applyFzf], ["neovim", applyNvim], ["gtk", applyGtk], ["qt", applyQt]]) {
        try {
            step(colors);
        } catch (error) {  // um programa com problema não trava os outros
            warn(`${name}: ${error.message}`);
            failed = true;
        }
    }
    return failed ? 1 : 0;
}

process.exitCode = main();
