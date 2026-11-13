import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

// Bluetooth (BlueZ): status na barra; clique abre o painel com os
// dispositivos pareados, a busca por novos e a qualidade do áudio.
//
// Substitui o blueman:
//  - dispositivos: Quickshell.Bluetooth (nativo);
//  - agente de pareamento (confirmar código, PIN): "bluetoothctl --agent"
//    rodando em segundo plano; os pedidos aparecem no painel;
//  - perfil/codec de áudio: pactl.
BarButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var pairedDevices: devices.filter(d => d.paired)
            .sort((a, b) => (b.connected - a.connected) || deviceName(a).localeCompare(deviceName(b)))
    // novos: só os que têm nome (o resto é ruído de BLE)
    readonly property var newDevices: devices.filter(d => !d.paired && d.deviceName !== "")
    readonly property var connectedDevices: pairedDevices.filter(d => d.connected)

    function deviceName(d) {
        return d.name || d.deviceName || d.address;
    }

    function deviceIcon(d) {
        const icon = d.icon || "";
        if (icon.startsWith("audio"))
            return "󰋋";
        if (icon === "input-keyboard")
            return "󰌌";
        if (icon === "input-mouse")
            return "󰍽";
        if (icon === "input-gaming")
            return "󰊴";
        if (icon.startsWith("phone"))
            return "󰏲";
        if (icon === "computer")
            return "󰟀";
        if (icon === "video-display")
            return "󰍹";
        return "󰂯";
    }

    // 0-100, ou -1 se o dispositivo não informa
    function batteryPercent(d) {
        if (!d.batteryAvailable)
            return -1;
        return Math.round(d.battery <= 1 ? d.battery * 100 : d.battery);
    }

    // ---- botão na barra -------------------------------------------------------

    visible: adapter !== null

    icon: !powered ? "󰂲" : connectedDevices.length > 0 ? "󰂱" : "󰂯"
    label: ""      // o nome do dispositivo fica no painel
    accent: "secondary"
    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
    }

    // ---- ações ------------------------------------------------------------------

    function setPowered(on) {
        if (adapter)
            adapter.enabled = on;
    }

    function setDiscovering(on) {
        if (adapter && adapter.enabled && adapter.discovering !== on)
            adapter.discovering = on;
    }

    property var pendingDevice: null   // dispositivo sendo pareado pelo painel
    property string errorAddress: ""
    property string errorText: ""

    function pairDevice(d) {
        errorAddress = "";
        pendingDevice = d;
        d.pair();
    }

    function connectDevice(d) {
        errorAddress = "";
        d.connect();
    }

    // depois de parear: confiar (reconecta sozinho no futuro) e conectar
    Connections {
        target: root.pendingDevice
        ignoreUnknownSignals: true

        function onPairedChanged() {
            const d = root.pendingDevice;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
                root.pendingDevice = null;
                root.prompt = null;
            }
        }

        function onPairingChanged() {
            const d = root.pendingDevice;
            if (d && !d.pairing && !d.paired) {
                root.errorAddress = d.address;
                root.errorText = "Não foi possível parear. Coloque o dispositivo em modo de pareamento e tente de novo.";
                root.pendingDevice = null;
                root.prompt = null;
            }
        }
    }

    // ---- agente de pareamento -----------------------------------------------------
    // O bluetoothctl registra um agente no BlueZ e pergunta pelo stdin; aqui a
    // saída dele é lida e os pedidos viram "prompt", respondido pelo painel.
    //
    // prompt: { kind, code }
    //   confirm   - confirmar se o código bate com o do dispositivo (sim/não)
    //   accept    - aceitar o pareamento (sim/não)
    //   authorize - permitir um serviço (sim/não)
    //   pin       - digitar um PIN
    //   passkey   - digitar uma senha numérica
    //   display   - mostrar um código para digitar no dispositivo
    property var prompt: null
    property string agentBuffer: ""

    function respond(answer) {
        if (agent.running)
            agent.write(answer + "\n");
        if (prompt && prompt.kind !== "display")
            prompt = null;
    }

    function agentOutput(data) {
        // tira cores e marcas do readline
        let text = agentBuffer + data.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/[\x01\x02\r]/g, "");
        let m;

        if ((m = /Confirm passkey (\d+) \(yes\/no\):/.exec(text)))
            prompt = { kind: "confirm", code: m[1] };
        else if (/Accept pairing \(yes\/no\):/.test(text))
            prompt = { kind: "accept", code: "" };
        else if ((m = /Authorize service (\S+) \(yes\/no\):/.exec(text)))
            prompt = { kind: "authorize", code: m[1] };
        else if (/Enter PIN code:/.test(text))
            prompt = { kind: "pin", code: "" };
        else if (/Enter passkey \(number in 0-999999\):/.test(text))
            prompt = { kind: "passkey", code: "" };
        else if ((m = /\[agent\] (?:PIN code|Passkey): (\d+)/.exec(text)))
            prompt = { kind: "display", code: m[1] };
        else if (/Request canceled/.test(text))
            prompt = null;
        else {
            // nada reconhecido ainda: guarda só o fim (o pedido pode vir em partes)
            agentBuffer = text.slice(-400);
            return;
        }

        agentBuffer = "";
        if (prompt && !popup.visible)
            togglePanel();      // pedido de pareamento abre o painel
    }

    Process {
        id: agent

        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        running: true
        stdinEnabled: true
        environment: ({ "LC_ALL": "C" })

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.agentOutput(data)
        }

        onRunningChanged: {
            if (running)
                write("default-agent\n");
        }
        onExited: agentRestart.start()
    }

    Timer {
        id: agentRestart
        interval: 5000
        onTriggered: agent.running = true
    }

    // ---- áudio: perfil/codec (pactl) ----------------------------------------------

    CommandRunner { id: commands }

    // endereço -> { card, active, profiles: [{ name, label, headset }] }
    property var audioCards: ({})

    function profileLabel(name, description) {
        const codec = (/codec ([^)]+)\)/.exec(description) || [])[1] || name;
        return name.startsWith("headset") ? "Microfone · " + codec : codec;
    }

    function refreshCards() {
        commands.run(["pactl", "-f", "json", "list", "cards"], (code, out) => {
            if (code !== 0)
                return;
            let list;
            try {
                list = JSON.parse(out);
            } catch (error) {
                return;
            }
            const cards = {};
            for (const card of list) {
                const address = card.properties && card.properties["api.bluez5.address"];
                if (!address)
                    continue;
                const profiles = Object.entries(card.profiles)
                    .filter(([name, p]) => name !== "off" && p.available)
                    .map(([name, p]) => ({
                        name: name,
                        label: profileLabel(name, p.description),
                        headset: name.startsWith("headset"),
                        priority: p.priority
                    }))
                    .sort((a, b) => (a.headset - b.headset) || (b.priority - a.priority));
                cards[address] = { card: card.name, active: card.active_profile, profiles: profiles };
            }
            audioCards = cards;
        });
    }

    function setProfile(address, profile) {
        const info = audioCards[address];
        if (info)
            commands.run(["pactl", "set-card-profile", info.card, profile], () => refreshCards());
    }

    Timer {
        interval: 3000
        repeat: true
        running: popup.visible
        triggeredOnStart: true
        onTriggered: root.refreshCards()
    }

    // ---- painel -----------------------------------------------------------------

    // a procura só começa pelo botão do painel: procurar dispositivos usa o
    // mesmo rádio do áudio e picota o som de um fone conectado
    function togglePanel() {
        popup.visible = !popup.visible;
        if (popup.visible)
            errorAddress = "";
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        onVisibleChanged: {
            if (!visible)
                root.setDiscovering(false);
        }

        BluetoothPanel {
            id: panel

            anchors.fill: parent
            bt: root
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call bluetooth togglePanel
    IpcHandler {
        target: "bluetooth"
        function togglePanel(): void { root.togglePanel(); }
    }
}
