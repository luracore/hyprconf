import Quickshell
import Quickshell.Io
import QtQuick

import qs.config

// Brilho do monitor externo via DDC/CI (ddcutil)
// scroll: ±5% · atalhos (IPC up/down): ±10% · clique: relê o valor do monitor
BarButton {
    id: root

    property string bus: ""        // número do /dev/i2c-N, detectado no início
    property int brightness: -1    // 0-100, -1 = desconhecido
    property int maxValue: 100
    property int target: -1        // valor pendente para gravar
    readonly property int step: 5        // scroll
    readonly property int keyStep: 10    // atalhos do Hyprland (IPC up/down)

    visible: bus !== ""

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
        if (bus === "" || brightness < 0)
            return;
        target = Math.max(0, Math.min(100, Math.round(v)));
        brightness = target;      // atualiza a barra na hora
        writeDebounce.restart();  // e grava no monitor depois de parar de rolar
    }

    function refresh() {
        if (bus !== "" && !readProc.running && !writeProc.running && target < 0)
            readProc.running = true;
    }

    // acha o barramento i2c do monitor
    Process {
        running: true
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/\/dev\/i2c-(\d+)/);
                if (m) {
                    root.bus = m[1];
                    root.refresh();
                } else {
                    console.warn("Brightness: nenhum monitor com DDC/CI encontrado");
                }
            }
        }
    }

    // lê: "VCP 10 C <atual> <max>"
    Process {
        id: readProc
        command: ["ddcutil", "--bus", root.bus, "--brief", "getvcp", "10"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m && root.target < 0) {
                    root.maxValue = Number(m[2]) || 100;
                    root.brightness = Math.round(Number(m[1]) * 100 / root.maxValue);
                }
            }
        }
    }

    Process {
        id: writeProc
    }

    Timer {
        id: writeDebounce
        interval: 250
        onTriggered: {
            if (writeProc.running) {
                restart();
                return;
            }
            const raw = Math.round(root.target * root.maxValue / 100);
            writeProc.command = ["ddcutil", "--bus", root.bus, "--noverify", "setvcp", "10", String(raw)];
            writeProc.running = true;
            root.target = -1;
        }
    }

    // pega mudanças feitas pelos botões do monitor
    Timer {
        interval: 60000
        running: root.bus !== ""
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
