import Quickshell
import Quickshell.Networking
import QtQuick

Item {
    id: root
    visible: false

    property bool popupVisible: false
    property var cachedWifiNetworks: []

    readonly property bool available:
        Networking.backend !== NetworkBackendType.None

    readonly property bool wifiEnabled:
        Networking.wifiEnabled && Networking.wifiHardwareEnabled

    readonly property bool scanning:
        rawWifiDevice ? rawWifiDevice.scannerEnabled : false

    // 1. Mapeia o estado de conectividade global do Quickshell
    readonly property string connectivity: {
        switch (Networking.connectivity) {
            case NetworkConnectivity.Portal: return "portal";
            case NetworkConnectivity.Limited: return "limited";
            case NetworkConnectivity.Full: return "full";
            default: return "none";
        }
    }

    // 2. Lista os dispositivos cabeadas (Ethernet) no formato esperado pelo NetworkPanel.qml
    readonly property var wiredDevices: {
        const list = [];
        const devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) {
            const dev = devs[i];
            if (!(dev instanceof WifiDevice)) {
                const net = dev.network;
                const connected = net ? net.connected : false;
                // No painel: "connected" = conectado, "unavailable" = cabo desconectado
                const state = connected ? "connected" : (net ? "disconnected" : "unavailable");

                list.push({
                    raw: dev,
                    device: dev.name,
                    connection: net ? (net.name || dev.name) : "",
                    state: state
                });
            }
        }
        return list;
    }

    // 3. Indica se algum dispositivo cabeado está conectado
    readonly property bool wiredConnected:
        wiredDevices.some(d => d.state === "connected")

    readonly property var rawWifiDevice: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            const dev = Networking.devices.values[i];
            if (dev instanceof WifiDevice)
                return dev;
        }
        return null;
    }

    readonly property var wifiDevice:
        rawWifiDevice
        ? { device: rawWifiDevice.name, raw: rawWifiDevice }
        : null

    readonly property var activeWifi: {
        if (!rawWifiDevice)
            return null;

        const networks = rawWifiDevice.networks.values;

        for (let i = 0; i < networks.length; i++) {
            const net = networks[i];

            if (net.connected && net.name) {
                return {
                    raw: net,
                    ssid: net.name,
                    signal: Math.round((net.signalStrength || 0) * 100),
                    inUse: true
                };
            }
        }

        return null;
    }

    readonly property var wifiNetworks:
        cachedWifiNetworks

    function updateWifiNetworks() {
        if (!rawWifiDevice)
            return;

        const bySsid = Object.create(null);
        const networks = rawWifiDevice.networks.values;

        for (let i = 0; i < networks.length; i++) {
            const net = networks[i];

            if (!net.name)
                continue;

            const sec = net.security;

            const enterprise =
                sec === WifiSecurityType.Wpa2Enterprise ||
                sec === WifiSecurityType.Wpa3Enterprise;

            const secured = sec !== WifiSecurityType.Open;

            const security =
                sec === WifiSecurityType.Wpa3 ? "WPA3" :
                sec === WifiSecurityType.Wep ? "WEP" :
                secured ? "WPA2" : "";

            const signal = Math.round(
                (net.signalStrength || 0) * 100
            );

            const item = {
                raw: net,
                ssid: net.name,
                signal: signal,
                security: security,
                inUse: net.connected,
                known: net.known,
                enterprise: enterprise,
                secured: secured
            };

            const prev = bySsid[net.name];

            if (!prev || item.inUse ||
                (!prev.inUse && item.signal > prev.signal)) {
                bySsid[net.name] = item;
            }
        }

        cachedWifiNetworks = Object.values(bySsid).sort(
            (a, b) =>
                (b.inUse - a.inUse) ||
                (b.known - a.known) ||
                (b.signal - a.signal)
        );
    }

    Timer {
        id: scanDelayTimer
        interval: 300

        onTriggered: {
            if (root.popupVisible &&
                root.rawWifiDevice &&
                root.wifiEnabled) {

                root.rawWifiDevice.scannerEnabled = true;
            }
        }
    }

    Timer {
        id: updateTimer
        interval: 500
        repeat: true

        onTriggered: {
            if (root.popupVisible)
                root.updateWifiNetworks();
        }
    }

    onPopupVisibleChanged: {
        if (popupVisible) {
            updateWifiNetworks();
            updateTimer.start();
            scanDelayTimer.restart();
        } else {
            scanDelayTimer.stop();
            updateTimer.stop();

            // Não desligamos o scanner aqui.
            // Evita operações desnecessárias no backend.
        }
    }

    function rescan() {
        if (rawWifiDevice && wifiEnabled) {
            rawWifiDevice.scannerEnabled = false;
            rawWifiDevice.scannerEnabled = true;
        }
    }

    function refresh() {
        rescan();
        updateWifiNetworks();
    }
}
