import Quickshell
import Quickshell.Io
import QtQuick

import "network" as NetworkComponents

BarButton {
    id: root

    NetworkComponents.NetworkService {
        id: service
        popupVisible: popup.visible
    }

    NetworkComponents.NetworkConnection {
        id: connection
        networkService: service
    }

    // Estado disponibilizado para a barra e o painel
    readonly property var wifiNetworks: service.wifiNetworks
    readonly property bool available: service.available
    readonly property bool wifiEnabled: service.wifiEnabled
    readonly property string connectivity: service.connectivity
    readonly property bool scanning: service.scanning

    readonly property var wiredDevices: service.wiredDevices
    readonly property var wifiDevice: service.wifiDevice
    readonly property var activeWifi: service.activeWifi
    readonly property bool wiredConnected: service.wiredConnected

    // Estado das operações de conexão
    property alias busySsid: connection.busySsid
    property alias errorSsid: connection.errorSsid
    property alias errorText: connection.errorText

    function signalIcon(signal) {
        return signal >= 75 ? "󰤨" : signal >= 50 ? "󰤥" : signal >= 25 ? "󰤢" : "󰤟";
    }

    visible: available

    onAvailableChanged: if (!available)
        popup.visible = false

    icon: activeWifi ? signalIcon(activeWifi.signal) : wiredConnected ? "󰈀" : wifiDevice && wifiEnabled ? "󰤯" : "󰤮"

    label: ""

    accent: connectivity === "portal" || connectivity === "limited" ? "warning" : activeWifi || wiredConnected ? "info" : "error"

    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
    }

    // Consultas
    function refresh() {
        service.refresh();
    }
    function rescan() {
        service.rescan();
    }

    // Operações de conexão
    function connectKnown(ssid) {
        connection.connectKnown(ssid);
    }
    function connectPsk(ssid, password, hidden) {
        connection.connectPsk(ssid, password, hidden);
    }
    function connectEnterprise(ssid, options) {
        connection.connectEnterprise(ssid, options);
    }
    function disconnectWifi() {
        connection.disconnectWifi();
    }
    function forget(ssid) {
        connection.forget(ssid);
    }
    function setWifiEnabled(enabled) {
        connection.setWifiEnabled(enabled);
    }
    function setWiredConnected(device, connected) {
        connection.setWiredConnected(device, connected);
    }

    // Métodos auxiliares usados pelo painel
    function clearError() {
        connection.clearError();
    }

    function openAdvanced() {
    }

    function openPortalLogin() {
        popup.visible = false;
        Quickshell.execDetached(["xdg-open", "http://neverssl.com"]);
    }

    function togglePanel() {
        popup.visible = !popup.visible;

        if (popup.visible)
            clearError();
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        NetworkPanel {
            id: panel

            anchors.fill: parent
            net: root
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    IpcHandler {
        target: "network"

        function togglePanel() {
            root.togglePanel();
        }
        function rescan() {
            root.rescan();
        }
    }
}
