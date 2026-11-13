import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Estado dos monitores, usado pelo módulo de brilho e pelo painel:
//   - controles de brilho (um BrightnessControl por display controlável);
//   - monitores do Hyprland (hyprctl monitors all -j);
//   - mudanças de resolução, taxa, escala e posição: aplica na hora
//     (hyprctl eval) e pede confirmação; sem confirmar em 10 s, volta.
//     Confirmadas, vão para hypr/config/monitor-painel.lua;
//   - modo noturno (hyprsunset).
// Fica fora do painel: se o painel fechar no meio da confirmação, a contagem
// continua e a configuração antiga volta sozinha.
Item {
    id: root

    property var controls: []      // BrightnessControl
    // o da barra: a tela do notebook, se houver; senão, o primeiro monitor
    readonly property var primary: controls.length > 0 ? controls[0] : null

    property var monitors: []      // hyprctl monitors all -j (sem os desligados)

    // resolução, escala ou posição de algum monitor mudou: janelas já abertas
    // (como o painel) ficam borradas até serem recriadas
    signal geometryChanged
    property string geometryKey: ""
    property var saved: ({})       // output -> spec salvo no monitor-painel.lua

    // confirmação pendente
    property var previous: null    // spec para voltar
    property int countdown: 0
    readonly property bool pending: previous !== null

    property bool nightAvailable: false
    property bool nightOn: false
    property int nightTemp: 4500
    readonly property int nightMin: 2500
    readonly property int nightMax: 6000

    readonly property string savedPath: Quickshell.env("HOME") + "/hyprconf/hypr/config/monitor-painel.lua"
    readonly property string nightPath: Quickshell.env("HOME") + "/.local/state/hyprconf/nightlight"

    CommandRunner { id: commands }

    Component.onCompleted: {
        detectBrightness();
        refreshMonitors();
        commands.run(["sh", "-c", "command -v hyprsunset"], code => {
            nightAvailable = code === 0;
            if (nightAvailable)
                nightFile.reload();
        });
    }

    // ---- brilho ------------------------------------------------------------------

    Component {
        id: controlComponent
        BrightnessControl {}
    }

    function addControl(props) {
        controls = controls.concat([controlComponent.createObject(root, props)]);
    }

    // tela do notebook primeiro (vira a da barra), depois os monitores com DDC.
    // Via sh, para um programa que não está instalado só dar código de erro.
    function detectBrightness() {
        commands.run(["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -m -c backlight info"], (code, out) => {
            const fields = out.trim().split("\n")[0].split(",");
            if (code === 0 && fields.length >= 4)
                addControl({ backend: "backlight", device: fields[0] });

            detectDdc();
        });
    }

    // a detecção pelo DDC falha às vezes no login (barramento i2c ocupado por
    // outro ddcutil): sem achar nenhum monitor, tenta de novo algumas vezes
    property int ddcAttempts: 0

    function detectDdc() {
        ddcAttempts += 1;
        commands.run(["sh", "-c", "command -v ddcutil >/dev/null && ddcutil detect --terse"], (code, out) => {
            let found = false;
            // um bloco por display: "Display 1 / I2C bus: /dev/i2c-3 / DRM connector: card1-HDMI-A-1"
            for (const block of out.split(/\n(?=\S)/)) {
                if (!block.startsWith("Display"))
                    continue;
                const bus = block.match(/\/dev\/i2c-(\d+)/);
                const drm = block.match(/DRM connector:\s+card\d+-(\S+)/);
                if (bus) {
                    addControl({ backend: "ddc", device: bus[1], output: drm ? drm[1] : "" });
                    found = true;
                }
            }
            if (!found && ddcAttempts < 3)
                ddcRetry.start();
        });
    }

    Timer {
        id: ddcRetry
        interval: 5000
        onTriggered: root.detectDdc()
    }

    function isInternal(name) {
        return /^(eDP|LVDS|DSI)/.test(name);
    }

    function controlFor(name) {
        return controls.find(c => c.output === name || (c.output === "" && isInternal(name))) ?? null;
    }

    // ---- monitores -------------------------------------------------------------------

    function refreshMonitors() {
        commands.run(["hyprctl", "monitors", "all", "-j"], (code, out) => {
            try {
                monitors = JSON.parse(out).filter(m => !m.disabled);
            } catch (e) {
                return;
            }
            const key = monitors.map(m => [m.name, m.width, m.height, m.scale, m.x, m.y].join(":")).join(" ");
            if (geometryKey !== "" && key !== geometryKey)
                geometryChanged();
            geometryKey = key;
        });
    }

    // depois de aplicar: relê na hora e de novo quando o Hyprland já terminou
    // de reconfigurar (a primeira leitura às vezes ainda vem com o estado velho)
    function refreshSoon() {
        refreshMonitors();
        refreshLater.restart();
    }

    Timer {
        id: refreshLater
        interval: 700
        onTriggered: root.refreshMonitors()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2")
                root.refreshMonitors();
        }
    }

    // "1920x1080@74.97Hz" -> { res: "1920x1080", rate: 74.97, mode: "1920x1080@74.97" }
    function modesOf(mon) {
        return (mon.availableModes ?? []).map(s => {
            const m = s.match(/^(\d+x\d+)@([\d.]+)/);
            return m ? { res: m[1], rate: Number(m[2]), mode: m[1] + "@" + m[2] } : null;
        }).filter(m => m !== null);
    }

    function rateLabel(rate) {
        return (Math.abs(rate - Math.round(rate)) < 0.05 ? String(Math.round(rate)) : rate.toFixed(2).replace(".", ",")) + " Hz";
    }

    // configuração atual de um monitor, no formato do hl.monitor
    function specOf(mon) {
        const s = saved[mon.name] ?? {};
        // o hyprctl informa o espelhado pelo id; o hl.monitor quer o nome
        const mirrored = mon.mirrorOf && mon.mirrorOf !== "none"
            ? (monitors.find(m => String(m.id) === String(mon.mirrorOf))?.name ?? "") : "";
        return {
            output: mon.name,
            mode: mon.width + "x" + mon.height + "@" + mon.refreshRate.toFixed(2),
            position: s.position ?? "auto",
            scale: Number(mon.scale.toFixed(2)),
            mirror: mirrored
        };
    }

    // mirror vai sempre: sem o campo, o Hyprland mantém um espelho que já
    // existia; mirror = "" desfaz
    function luaOf(spec) {
        return 'hl.monitor({ output = "' + spec.output + '", mode = "' + spec.mode
            + '", position = "' + spec.position + '", scale = ' + spec.scale
            + ', mirror = "' + (spec.mirror ?? "") + '" })';
    }

    // muda um ou mais campos (mode, scale, position, mirror) de um monitor
    function change(mon, fields) {
        if (pending)
            return;
        const before = specOf(mon);
        const after = Object.assign({}, before, fields);
        if (luaOf(after) === luaOf(before))
            return;
        previous = before;
        next = after;
        countdown = 10;
        commands.run(["hyprctl", "eval", luaOf(after)], () => refreshSoon());
    }

    property var next: null

    function keep() {
        if (!pending)
            return;
        const s = Object.assign({}, saved);
        s[next.output] = next;
        saved = s;
        writeSaved();
        previous = null;
        next = null;
    }

    function revert() {
        if (!pending)
            return;
        commands.run(["hyprctl", "eval", luaOf(previous)], () => refreshSoon());
        previous = null;
        next = null;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pending
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    // monitor-painel.lua: uma linha hl.monitor({...}) por monitor
    FileView {
        id: savedFile
        path: root.savedPath
        printErrors: false
        onLoaded: {
            const s = {};
            for (const line of text().split("\n")) {
                const output = line.match(/output = "([^"]+)"/);
                if (!line.startsWith("hl.monitor(") || !output)
                    continue;
                const field = name => (line.match(new RegExp(name + ' = "([^"]*)"')) ?? [])[1];
                s[output[1]] = {
                    output: output[1],
                    mode: field("mode") ?? "preferred",
                    position: field("position") ?? "auto",
                    scale: Number((line.match(/scale = ([\d.]+)/) ?? [])[1] ?? 1),
                    mirror: field("mirror") ?? ""
                };
            }
            root.saved = s;
        }
    }

    function writeSaved() {
        const lines = [
            "-- Gerado pelo painel de monitores da barra (clique no brilho).",
            "-- Uma regra por monitor; vale por cima do monitor.lua. Pode apagar",
            "-- uma linha (ou o arquivo) para voltar ao padrão.",
            ""
        ];
        for (const output of Object.keys(saved).sort())
            lines.push(luaOf(saved[output]));
        savedFile.setText(lines.join("\n") + "\n");
    }

    // ---- modo noturno ------------------------------------------------------------------

    // ~/.local/state/hyprconf/nightlight: "on 4500" ou "off 4500"
    FileView {
        id: nightFile
        path: root.nightPath
        printErrors: false
        onLoaded: {
            const m = text().trim().match(/^(on|off)\s+(\d+)/);
            if (!m)
                return;
            root.nightTemp = Math.max(root.nightMin, Math.min(root.nightMax, Number(m[2])));
            if (m[1] === "on")
                root.setNight(true);
        }
    }

    function saveNight() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && echo "$2" > "$1"',
                                 "sh", nightPath, (nightOn ? "on " : "off ") + nightTemp]);
    }

    function setNight(on) {
        if (!nightAvailable)
            return;
        nightOn = on;
        if (on)
            Quickshell.execDetached(["sh", "-c", "pgrep -x hyprsunset >/dev/null || exec hyprsunset -t " + nightTemp]);
        else
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
        saveNight();
    }

    function setNightTemp(t) {
        nightTemp = Math.round(Math.max(nightMin, Math.min(nightMax, t)) / 100) * 100;
        if (nightOn)
            nightDebounce.restart();
        else
            saveNight();
    }

    Timer {
        id: nightDebounce
        interval: 150
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.nightTemp)]);
            root.saveNight();
        }
    }
}
