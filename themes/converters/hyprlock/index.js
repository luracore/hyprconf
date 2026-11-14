"use strict";

const os = require("os");
const path = require("path");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "hypr/hyprlock-current.conf");

function generate(c) {
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
    return "# Gerado por hyprconf/themes/converters/hyprlock — não edite.\n"
        + Object.entries(vars).map(([k, v]) => `$${k} = ${rgb(v)}\n`).join("");
}

module.exports = { target: TARGET, generate };
