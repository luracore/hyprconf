import QtQuick

// Brilho de um display, por um destes caminhos:
//   backlight - tela de notebook (/sys/class/backlight), via brightnessctl
//   ddc       - monitor externo com DDC/CI, via ddcutil
// Criado pelo Displays.qml, um para cada display que dá para controlar.
Item {
    id: root

    property string output: ""     // nome no Hyprland (eDP-1, HDMI-A-1); vazio = tela interna
    property string backend: ""    // "backlight" | "ddc"
    property string device: ""     // backlight: nome do dispositivo · ddc: número do /dev/i2c-N
    property int brightness: -1    // 0-100, -1 = ainda não leu
    property int maxValue: 100     // ddc: valor máximo do monitor
    property int target: -1        // valor pendente para gravar
    property bool writing: false

    readonly property bool ready: brightness >= 0

    function set(v) {
        if (!ready)
            return;
        // na tela do notebook, 0% apagaria a tela de vez
        const min = backend === "backlight" ? 1 : 0;
        target = Math.max(min, Math.min(100, Math.round(v)));
        brightness = target;
        writeDebounce.restart();
    }

    function step(delta) {
        set((target >= 0 ? target : brightness) + delta);
    }

    function refresh() {
        if (writing || target >= 0)
            return;
        if (backend === "backlight")
            commands.run(["brightnessctl", "-m", "-d", device, "info"], (code, out) => {
                // "intel_backlight,backlight,512,40%,1200"
                const fields = out.trim().split(",");
                if (code === 0 && fields.length >= 4 && target < 0)
                    brightness = parseInt(fields[3]);
            });
        else
            commands.run(["ddcutil", "--bus", device, "--brief", "getvcp", "10"], (code, out) => {
                // "VCP 10 C <atual> <max>"
                const m = out.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                if (m && target < 0) {
                    maxValue = Number(m[2]) || 100;
                    brightness = Math.round(Number(m[1]) * 100 / maxValue);
                }
            });
    }

    Component.onCompleted: refresh()

    CommandRunner { id: commands }

    // gravação: uma de cada vez, com o último valor pedido
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
                ? ["brightnessctl", "-q", "-d", root.device, "set", value + "%"]
                : ["ddcutil", "--bus", root.device, "--noverify", "setvcp", "10",
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
    // inicialização); tenta de novo logo, em vez de esperar o ciclo longo
    Timer {
        interval: 3000
        running: !root.ready
        repeat: true
        onTriggered: root.refresh()
    }

    // pega mudanças feitas por fora (botões do monitor, outro programa)
    Timer {
        interval: root.backend === "backlight" ? 5000 : 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
