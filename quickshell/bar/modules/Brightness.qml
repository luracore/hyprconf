import Quickshell
import Quickshell.Io
import QtQuick

import qs.config

// Brilho da tela, com dois jeitos de controlar, detectados no início:
//   backlight - tela de notebook (/sys/class/backlight), via brightnessctl
//   ddc       - monitor externo com DDC/CI, via ddcutil
// Sem nenhum dos dois, o módulo não aparece.
//
// scroll: ±5% · atalhos (IPC up/down): ±10% · clique: relê o valor
BarButton {
    id: root

    property string backend: ""    // "backlight" | "ddc" | ""
    property string bus: ""        // ddc: número do /dev/i2c-N
    property int brightness: -1    // 0-100, -1 = desconhecido
    property int maxValue: 100     // ddc: valor máximo do monitor
    property int target: -1        // valor pendente para gravar
    readonly property int step: 5        // scroll
    readonly property int keyStep: 10    // atalhos do Hyprland (IPC up/down)

    visible: backend !== ""

    icon: brightness < 34 ? "󰃞" : brightness < 67 ? "󰃟" : "󰃠"
    label: brightness < 0 ? "--" : brightness + "%"
    labelTemplate: "100%"
    accent: "warning"

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.refresh();
    }
    onScrolled: steps => root.setBrightness((target >= 0 ? target : brightness) + steps * step)

    function setBrightness(v) {
        if (backend === "" || brightness < 0)
            return;
        // no notebook, 0% apagaria a tela de vez
        const min = backend === "backlight" ? 1 : 0;
        target = Math.max(min, Math.min(100, Math.round(v)));
        brightness = target;      // atualiza a barra na hora
        writeDebounce.restart();  // e grava depois de parar de rolar
    }

    function refresh() {
        if (backend === "" || writing || target >= 0)
            return;
        if (backend === "backlight")
            commands.run(["brightnessctl", "-m", "-c", "backlight", "info"], (code, out) => parseBacklight(code, out));
        else
            commands.run(["ddcutil", "--bus", bus, "--brief", "getvcp", "10"], (code, out) => {
                // "VCP 10 C <atual> <max>"
                const m = out.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m && target < 0) {
                    maxValue = Number(m[2]) || 100;
                    brightness = Math.round(Number(m[1]) * 100 / maxValue);
                }
            });
    }

    // "intel_backlight,backlight,512,40%,1200"
    function parseBacklight(code, out) {
        const fields = out.trim().split("\n")[0].split(",");
        if (code !== 0 || fields.length < 4)
            return false;
        if (target < 0)
            brightness = parseInt(fields[3]);
        return true;
    }

    CommandRunner { id: commands }

    // detecção: tela de notebook primeiro; senão, monitor externo.
    // Via sh, para um programa que não está instalado só dar código de erro.
    Component.onCompleted: {
        commands.run(["sh", "-c", "command -v brightnessctl >/dev/null && brightnessctl -m -c backlight info"], (code, out) => {
            if (parseBacklight(code, out)) {
                backend = "backlight";
                return;
            }
            commands.run(["sh", "-c", "command -v ddcutil >/dev/null && ddcutil detect --terse"], (code2, out2) => {
                const m = out2.match(/\/dev\/i2c-(\d+)/);
                if (m) {
                    bus = m[1];
                    backend = "ddc";
                    refresh();
                }
            });
        });
    }

    // gravação: uma de cada vez, com o último valor pedido
    property bool writing: false

    Timer {
        id: writeDebounce
        interval: 250
        onTriggered: {
            if (root.writing) {
                restart();
                return;
            }
            const value = root.target;
            const args = root.backend === "backlight"
                ? ["brightnessctl", "-q", "-c", "backlight", "set", value + "%"]
                : ["ddcutil", "--bus", root.bus, "--noverify", "setvcp", "10",
                   String(Math.round(value * root.maxValue / 100))];
            root.writing = true;
            commands.run(args, () => {
                root.writing = false;
                if (root.target === value)
                    root.target = -1;
            });
        }
    }

    // a primeira leitura do DDC pode falhar (barramento i2c ocupado na
    // inicialização); tenta de novo logo, em vez de esperar o ciclo de 60s
    Timer {
        interval: 3000
        running: root.backend !== "" && root.brightness < 0
        repeat: true
        onTriggered: root.refresh()
    }

    // pega mudanças feitas por fora (botões do monitor, outro programa)
    Timer {
        interval: root.backend === "backlight" ? 5000 : 60000
        running: root.backend !== ""
        repeat: true
        onTriggered: root.refresh()
    }

    // qs ipc call brightness up|down|set 50
    IpcHandler {
        target: "brightness"
        function up(): void { root.setBrightness((root.target >= 0 ? root.target : root.brightness) + root.keyStep); }
        function down(): void { root.setBrightness((root.target >= 0 ? root.target : root.brightness) - root.keyStep); }
        function set(percent: int): void { root.setBrightness(percent); }
    }
}
