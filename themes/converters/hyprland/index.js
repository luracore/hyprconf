"use strict";

const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const TARGET = path.join(CONFIG, "hypr/config/current.lua");

const settings = c => `{ misc = { background_color = 0xff${c.background.slice(1).toLowerCase()} } }`;

function generate(c) {
    return `hl.config(${settings(c)})\n`;
}

function apply(c) {
    spawnSync("hyprctl", ["eval", `hl.config(${settings(c)})`], { stdio: "ignore" });
}

module.exports = { target: TARGET, generate, apply };
