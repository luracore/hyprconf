import Quickshell
import Quickshell.Io
import QtQuick

// Consulta o estado do NetworkManager, dispositivos, redes e perfis salvos.
// Não executa operações de conexão ou desconexão.
Item {
    id: root

    visible: false

    // O executor é fornecido pelo Network.qml.
    property var commandRunner: null
    property bool popupVisible: false

    property var devices: []
    property var wifiNetworks: []
    property var savedWifi: []

    property bool available: false
    property bool wifiEnabled: false
    property string connectivity: "unknown"
    property bool scanning: false

    // Identificadores das consultas mais recentes.
    property int availabilityGeneration: 0
    property int wifiStateGeneration: 0
    property int connectivityGeneration: 0
    property int profilesGeneration: 0
    property int devicesGeneration: 0
    property int wifiListGeneration: 0

    readonly property var wiredDevices: devices.filter(d => d.type === "ethernet")
    readonly property var wifiDevice: devices.find(d => d.type === "wifi") ?? null
    readonly property var activeWifi: wifiNetworks.find(n => n.inUse) ?? null
    readonly property bool wiredConnected: wiredDevices.some(d => d.state === "connected")

    function run(args, callback) {
        if (commandRunner)
            commandRunner.run(args, callback);
    }

    // Campos da saída "nmcli -t": separados por ":", com "\:" e "\\" escapados.
    function terse(line) {
        const fields = [];
        let current = "";

        for (let i = 0; i < line.length; i++) {
            const ch = line[i];

            if (ch === "\\" && i + 1 < line.length) {
                current += line[++i];
            } else if (ch === ":") {
                fields.push(current);
                current = "";
            } else {
                current += ch;
            }
        }

        fields.push(current);
        return fields;
    }

    function lines(text) {
        return text.split("\n").filter(l => l.length > 0);
    }

    // SSID real de cada perfil Wi-Fi; o nome do perfil não é necessariamente o SSID.
    function listWifiProfiles(callback) {
        run(["nmcli", "-t", "-f", "UUID,TYPE,TIMESTAMP", "connection", "show"], (code, out) => {
            if (code !== 0) {
                callback(null);
                return;
            }

            const base = lines(out).map(terse)
                .filter(f => f[1] === "802-11-wireless")
                .map(f => ({
                    uuid: f[0],
                    timestamp: Number(f[2]) || 0
                }));

            if (base.length === 0) {
                callback([]);
                return;
            }

            let pending = base.length;
            let failed = false;
            const profiles = [];

            for (const profile of base) {
                run([
                    "nmcli", "-t", "-g", "802-11-wireless.ssid",
                    "connection", "show", "uuid", profile.uuid
                ], (ssidCode, ssidOut) => {
                    if (ssidCode !== 0) {
                        failed = true;
                    } else {
                        const ssid = terse(ssidOut.replace(/\n$/, ""))[0] ?? "";

                        if (ssid !== "")
                            profiles.push(Object.assign({}, profile, { ssid: ssid }));
                    }

                    if (--pending === 0)
                        callback(failed ? null : profiles);
                });
            }
        });
    }

    function refreshSavedWifi(callback) {
        const generation = ++profilesGeneration;

        listWifiProfiles(profiles => {
            // Ignora uma consulta substituída por outra mais recente.
            if (generation !== profilesGeneration)
                return;

            if (profiles !== null)
                savedWifi = profiles;

            if (callback)
                callback();
        });
    }

    function refresh() {
        const generation = ++availabilityGeneration;

        run(["nmcli", "-t", "-f", "RUNNING", "general"], (code, out) => {
            if (generation !== availabilityGeneration)
                return;

            available = code === 0 && out.trim() === "running";

            if (available)
                refreshAll();
        });
    }

    function refreshAll() {
        const wifiGeneration = ++wifiStateGeneration;
        const connectivityId = ++connectivityGeneration;

        run(["nmcli", "radio", "wifi"], (code, out) => {
            if (wifiGeneration !== wifiStateGeneration)
                return;

            wifiEnabled = code === 0 && out.trim() === "enabled";
        });

        run(["nmcli", "networking", "connectivity"], (code, out) => {
            if (connectivityId !== connectivityGeneration)
                return;

            connectivity = code === 0 ? (out.trim() || "unknown") : "unknown";
        });

        if (!popupVisible) {
            refreshDevices();
            return;
        }

        refreshSavedWifi(refreshDevices);
    }

    function refreshDevices() {
        const generation = ++devicesGeneration;

        run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"], (code, out) => {
            if (generation !== devicesGeneration || code !== 0)
                return;

            devices = lines(out).map(l => {
                const f = terse(l);

                return {
                    device: f[0],
                    type: f[1],
                    state: f[2],
                    connection: f[3]
                };
            }).filter(d => d.type === "ethernet" || d.type === "wifi");

            refreshWifiList();
        });
    }

    function refreshWifiList() {
        const generation = ++wifiListGeneration;
        const device = wifiDevice;

        if (!device) {
            wifiNetworks = [];
            return;
        }

        // Usa um retrato dos perfis no momento em que a consulta começou.
        const profiles = savedWifi;

        run([
            "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "--rescan", "no"
        ], (code, out) => {
            if (generation !== wifiListGeneration || code !== 0)
                return;

            // O dispositivo pode ter mudado enquanto o comando executava.
            if (!wifiDevice || wifiDevice.device !== device.device)
                return;

            const bySsid = Object.create(null);

            for (const line of lines(out)) {
                const f = terse(line);
                const ssid = f[1];

                if (!ssid)
                    continue;

                const security = f[3] === "--" ? "" : f[3];

                const net = {
                    ssid: ssid,
                    signal: Number(f[2]) || 0,
                    security: security,
                    inUse: f[0] === "*",
                    known: profiles.some(p => p.ssid === ssid),
                    enterprise: security.includes("802.1X"),
                    secured: security !== "" && !/^OWE/.test(security)
                };

                const prev = bySsid[ssid];

                if (!prev || net.inUse || (!prev.inUse && net.signal > prev.signal))
                    bySsid[ssid] = net;
            }

            wifiNetworks = Object.values(bySsid).sort((a, b) =>
                (b.inUse - a.inUse) ||
                (b.known - a.known) ||
                (b.signal - a.signal));
        });
    }

    function rescan() {
        if (!wifiDevice || !wifiEnabled || scanning)
            return;

        scanning = true;

        run(["nmcli", "device", "wifi", "rescan"], () => rescanWait.restart());
    }

    // Atualiza quando o NetworkManager muda alguma coisa.
    Process {
        id: monitor

        running: true
        command: ["nmcli", "monitor"]
        environment: ({ "LC_ALL": "C" })

        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }

        onExited: monitorRestart.start()
    }

    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: monitor.running = true
    }

    Timer {
        id: refreshDebounce
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: rescanWait
        interval: 2500

        onTriggered: {
            root.scanning = false;
            root.refreshWifiList();
        }
    }

    // O sinal das redes muda sem eventos; relê enquanto o painel está aberto.
    Timer {
        interval: 10000
        repeat: true
        running: root.popupVisible
        onTriggered: root.refreshWifiList()
    }

    Component.onCompleted: refresh()
}
