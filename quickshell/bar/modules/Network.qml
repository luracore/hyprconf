import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

import "../config/Sizes.js" as Sizes
import qs.config

// Rede (NetworkManager, via nmcli): status na barra; clique abre o painel com
// cabo, Wi-Fi (senha comum e corporativa/802.1X) e rede oculta.
//
// Usa nmcli para tudo porque o Quickshell.Networking (0.3) não expõe a rede
// cabeada nem consegue criar conexões 802.1X. Os comandos rodam com
// LC_ALL=C para a saída não depender do idioma do sistema.
BarButton {
    id: root

    // ---- estado (preenchido pelo refresh) -----------------------------------

    property var devices: []          // [{ device, type, state, connection }]
    property var wifiNetworks: []     // [{ ssid, signal, security, inUse, known, secured, enterprise }]
    property var savedWifi: []        // nomes das conexões Wi-Fi salvas
    property bool wifiEnabled: false
    property string connectivity: "unknown"   // none | portal | limited | full | unknown
    property bool scanning: false

    property string busySsid: ""      // rede em conexão
    property string errorSsid: ""     // rede da última falha
    property string errorText: ""
    property bool errorNeedsCredentials: false

    readonly property var wiredDevices: devices.filter(d => d.type === "ethernet")
    readonly property var wifiDevice: devices.find(d => d.type === "wifi") ?? null
    readonly property var activeWifi: wifiNetworks.find(n => n.inUse) ?? null
    readonly property bool wiredConnected: wiredDevices.some(d => d.state === "connected")

    // ---- botão na barra -------------------------------------------------------

    function signalIcon(signal) {
        return signal >= 75 ? "󰤨" : signal >= 50 ? "󰤥" : signal >= 25 ? "󰤢" : "󰤟";
    }

    icon: activeWifi ? signalIcon(activeWifi.signal)
        : wiredConnected ? "󰈀"
        : wifiDevice && wifiEnabled ? "󰤯"
        : "󰤮"
    label: activeWifi ? (activeWifi.ssid.length > 14 ? activeWifi.ssid.slice(0, 13) + "…" : activeWifi.ssid)
        : wiredConnected ? "cabo"
        : "off"
    accent: connectivity === "portal" || connectivity === "limited" ? "warning"
        : activeWifi || wiredConnected ? "info"
        : "error"
    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
    }

    // ---- comandos -------------------------------------------------------------

    CommandRunner { id: commands }

    function run(args, callback) {
        commands.run(args, callback);
    }

    // vários comandos em sequência; para no primeiro que falhar
    function runAll(list, callback) {
        if (list.length === 0) {
            callback(0, "", "");
            return;
        }
        run(list[0], (code, out, err) => {
            if (code !== 0)
                callback(code, out, err);
            else
                runAll(list.slice(1), callback);
        });
    }

    // campos da saída "nmcli -t": separados por ":", com "\:" e "\\" escapados
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

    function cleanError(text) {
        return text.trim().split("\n").pop().replace(/^Error:\s*/, "") || "falha desconhecida";
    }

    // ---- leitura ----------------------------------------------------------------

    function refresh() {
        run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"], (code, out) => {
            if (code !== 0)
                return;
            devices = lines(out).map(l => {
                const f = terse(l);
                return { device: f[0], type: f[1], state: f[2], connection: f[3] };
            }).filter(d => d.type === "ethernet" || d.type === "wifi");
            refreshWifiList();
        });

        run(["nmcli", "radio", "wifi"], (code, out) => wifiEnabled = out.trim() === "enabled");
        run(["nmcli", "networking", "connectivity"], (code, out) => connectivity = out.trim() || "unknown");
        run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], (code, out) => {
            savedWifi = lines(out).map(terse).filter(f => f[1] === "802-11-wireless").map(f => f[0]);
        });
    }

    function refreshWifiList() {
        if (!wifiDevice) {
            wifiNetworks = [];
            return;
        }
        run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"], (code, out) => {
            if (code !== 0)
                return;
            const bySsid = {};
            for (const line of lines(out)) {
                const f = terse(line);
                const ssid = f[1];
                if (!ssid)
                    continue;    // ocultas aparecem sem nome; use "Rede oculta…"
                const security = f[3] === "--" ? "" : f[3];
                const net = {
                    ssid: ssid,
                    signal: Number(f[2]) || 0,
                    security: security,
                    inUse: f[0] === "*",
                    known: savedWifi.includes(ssid),
                    enterprise: security.includes("802.1X"),
                    secured: security !== "" && !/^OWE/.test(security)
                };
                const prev = bySsid[ssid];
                if (!prev || net.inUse || (!prev.inUse && net.signal > prev.signal))
                    bySsid[ssid] = net;
            }
            wifiNetworks = Object.values(bySsid).sort((a, b) =>
                (b.inUse - a.inUse) || (b.known - a.known) || (b.signal - a.signal));
        });
    }

    function rescan() {
        if (!wifiDevice || !wifiEnabled || scanning)
            return;
        scanning = true;
        run(["nmcli", "device", "wifi", "rescan"], () => rescanWait.restart());
    }

    Timer {
        id: rescanWait
        interval: 2500
        onTriggered: {
            root.scanning = false;
            root.refreshWifiList();
        }
    }

    // atualiza quando o NetworkManager muda algo
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

    // sinal das redes muda sem eventos; relê enquanto o painel está aberto
    Timer {
        interval: 10000
        repeat: true
        running: popup.visible
        onTriggered: root.refreshWifiList()
    }

    Component.onCompleted: refresh()

    // ---- ações ------------------------------------------------------------------

    // errorSsid por último: o painel reage à mudança dele
    function setError(ssid, err, needsCredentials) {
        errorNeedsCredentials = needsCredentials;
        errorText = cleanError(err);
        errorSsid = ssid;
    }

    function clearError() {
        errorSsid = "";
        errorText = "";
        errorNeedsCredentials = false;
    }

    function looksLikeAuthError(err) {
        return /secrets|password|802-1x|supplicant|auth|key/i.test(err);
    }

    function finish(ssid, code, err, cleanup) {
        busySsid = "";
        if (code !== 0) {
            setError(ssid, err, looksLikeAuthError(err));
            if (cleanup)
                run(cleanup);
        }
        refreshDebounce.restart();
    }

    // Conecta numa rede já salva.
    function connectKnown(ssid) {
        clearError();
        busySsid = ssid;
        run(["nmcli", "connection", "up", "id", ssid], (code, out, err) => finish(ssid, code, err));
    }

    // Rede aberta ou com senha (WPA/WEP). hidden: rede oculta.
    function connectPsk(ssid, password, hidden) {
        clearError();
        busySsid = ssid;

        // rede salva com senha trocada: atualiza a senha e reconecta
        if (savedWifi.includes(ssid) && password !== "") {
            runAll([
                ["nmcli", "connection", "modify", "id", ssid, "wifi-sec.psk", password],
                ["nmcli", "connection", "up", "id", ssid]
            ], (code, out, err) => finish(ssid, code, err));
            return;
        }

        const args = ["nmcli", "device", "wifi", "connect", ssid];
        if (password !== "")
            args.push("password", password);
        if (hidden)
            args.push("hidden", "yes");
        if (wifiDevice)
            args.push("ifname", wifiDevice.device);
        // conexão nova que falhou não fica salva com a senha errada
        // (só apaga se ela não existia antes)
        const isNew = !savedWifi.includes(ssid);
        run(args, (code, out, err) => finish(ssid, code, err,
            isNew ? ["nmcli", "connection", "delete", "id", ssid] : null));
    }

    // Rede corporativa (WPA-Enterprise / 802.1X), ex. faculdade ou eduroam.
    // o: { identity, password, eap: "peap"|"ttls", phase2: "mschapv2"|"pap"|"gtc",
    //      anonymous, caCert, domain, hidden }
    function connectEnterprise(ssid, o) {
        clearError();
        busySsid = ssid;

        const props = [
            "wifi-sec.key-mgmt", "wpa-eap",
            "802-1x.eap", o.eap,
            "802-1x.phase2-auth", o.phase2,
            "802-1x.identity", o.identity,
            "802-1x.password", o.password
        ];
        if (o.anonymous)
            props.push("802-1x.anonymous-identity", o.anonymous);
        if (o.caCert)
            props.push("802-1x.ca-cert", o.caCert.replace(/^~(?=\/|$)/, Quickshell.env("HOME")));
        if (o.domain)
            props.push("802-1x.domain-suffix-match", o.domain);
        if (o.hidden)
            props.push("802-11-wireless.hidden", "yes");

        const exists = savedWifi.includes(ssid);
        const create = exists
            ? ["nmcli", "connection", "modify", "id", ssid].concat(props)
            : ["nmcli", "connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid]
                .concat(wifiDevice ? ["ifname", wifiDevice.device] : [])
                .concat(props);

        runAll([create, ["nmcli", "connection", "up", "id", ssid]], (code, out, err) =>
            finish(ssid, code, err, exists ? null : ["nmcli", "connection", "delete", "id", ssid]));
    }

    function disconnectWifi() {
        if (wifiDevice)
            run(["nmcli", "device", "disconnect", wifiDevice.device], () => refreshDebounce.restart());
    }

    function forget(ssid) {
        clearError();
        run(["nmcli", "connection", "delete", "id", ssid], () => refreshDebounce.restart());
    }

    function setWifiEnabled(enabled) {
        run(["nmcli", "radio", "wifi", enabled ? "on" : "off"], () => refreshDebounce.restart());
    }

    function setWiredConnected(device, connected) {
        run(["nmcli", "device", connected ? "connect" : "disconnect", device], () => refreshDebounce.restart());
    }

    function openAdvanced() {
        popup.visible = false;
        Quickshell.execDetached(["nm-connection-editor"]);
    }

    function openPortalLogin() {
        popup.visible = false;
        Quickshell.execDetached(["xdg-open", "http://neverssl.com"]);
    }

    // ---- painel -----------------------------------------------------------------

    property int grabAttempts: 0

    function togglePanel() {
        grabAttempts = 0;
        popup.visible = !popup.visible;
        if (popup.visible) {
            clearError();
            refresh();
            rescan();
        }
    }

    PopupWindow {
        id: popup

        anchor.item: root
        anchor.rect.width: root.width
        anchor.rect.height: root.height
        anchor.rect.x: (root.width - panel.implicitWidth) / 2
        anchor.rect.y: Sizes.bar.height - root.y + 6
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        color: "transparent"

        visible: false

        NetworkPanel {
            id: panel

            anchors.fill: parent
            net: root
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // fecha ao clicar fora (mesmo esquema do calendário)
    HyprlandFocusGrab {
        id: focusGrab

        windows: [popup]
        active: popup.visible

        onCleared: popup.visible = false
    }

    Timer {
        interval: 50
        repeat: true
        running: popup.visible && !focusGrab.active && root.grabAttempts < 20
        onTriggered: {
            root.grabAttempts += 1;
            focusGrab.active = false;
            focusGrab.active = true;
        }
    }

    // qs ipc call network togglePanel|rescan
    IpcHandler {
        target: "network"
        function togglePanel(): void { root.togglePanel(); }
        function rescan(): void { root.rescan(); }
    }
}
