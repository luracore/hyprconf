// O tema "system" do OpenCode sai da paleta do terminal, que o conversor do
// foot já troca, mas ele só relê a paleta quando o tema muda no cli.json:
// por isso troca o modo e volta.

"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const CONFIG = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
const CLI = path.join(CONFIG, "opencode/cli.json");

function apply() {
    let text, cli;
    try {
        text = fs.readFileSync(CLI, "utf8");
        cli = JSON.parse(text);
    } catch {
        return;
    }
    if (cli.theme?.name !== "system")
        return;

    const mode = cli.theme.mode === "light" ? "dark" : "light";
    const toggled = JSON.stringify({ ...cli, theme: { ...cli.theme, mode } });
    spawn("sh", ["-c", 'printf %s "$2" > "$1"; sleep 0.1; printf %s "$3" > "$1"',
        "opencode-reload", CLI, toggled, text], { detached: true, stdio: "ignore" }).unref();
}

module.exports = { apply };
