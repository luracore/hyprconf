import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

PanelSurface {
    id: root

    required property var bt           // o módulo Bluetooth (estado + ações)

    property string expanded: ""       // endereço do dispositivo aberto
    property string pinInput: ""

    implicitWidth: 400

    closesOnEscape: false
    onEscapePressed: {
        if (root.expanded !== "")
            root.expanded = "";
        else
            root.closeRequested();
    }

    function statusText(d) {
        if (d.pairing)
            return "pareando…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "conectando…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "desconectando…";
        const battery = bt.batteryPercent(d);
        const base = d.connected ? "conectado" : "pareado";
        return battery >= 0 ? base + "  ·  bateria " + battery + "%" : base;
    }

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        PanelTitle {
            Layout.fillWidth: true
            text: "BLUETOOTH"
        }

        PanelIconButton {
            visible: root.bt.powered
            icon: "󰑐"
            spinning: root.bt.adapter !== null && root.bt.adapter.discovering
            onClicked: root.bt.setDiscovering(!root.bt.adapter.discovering)
        }

        PanelSwitch {
            checked: root.bt.powered
            onToggled: root.bt.setPowered(!root.bt.powered)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.bt.prompt !== null
        implicitHeight: promptColumn.implicitHeight + 24
        radius: Sizes.radius.normal
        color: Qt.alpha(Theme.colors.primary, 0.12)
        border.width: 1
        border.color: Qt.alpha(Theme.colors.primary, 0.6)

        readonly property string kind: root.bt.prompt ? root.bt.prompt.kind : ""
        readonly property string code: root.bt.prompt ? root.bt.prompt.code : ""
        readonly property string deviceName: root.bt.pendingDevice ? root.bt.deviceName(root.bt.pendingDevice) : "o dispositivo"

        id: promptBox

        ColumnLayout {
            id: promptColumn

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small + 1
                text: {
                    switch (promptBox.kind) {
                    case "confirm": return "Confirme se " + promptBox.deviceName + " mostra este código:";
                    case "accept": return "Aceitar o pareamento com " + promptBox.deviceName + "?";
                    case "authorize": return "Permitir que " + promptBox.deviceName + " use um serviço do computador?";
                    case "pin": return "Digite o PIN de " + promptBox.deviceName + " (geralmente 0000 ou 1234):";
                    case "passkey": return "Digite a senha numérica mostrada em " + promptBox.deviceName + ":";
                    case "display": return "Digite este código em " + promptBox.deviceName + " e aperte Enter nele:";
                    }
                    return "";
                }
            }

            Text {
                visible: promptBox.kind === "confirm" || promptBox.kind === "display"
                text: promptBox.code
                color: Theme.colors.primary
                font.family: Typo.family
                font.pixelSize: 28
                font.weight: Typo.weight.bold
                font.letterSpacing: 4
            }

            PanelField {
                Layout.fillWidth: true
                visible: promptBox.kind === "pin" || promptBox.kind === "passkey"
                label: promptBox.kind === "pin" ? "PIN" : "Senha numérica"
                value: root.pinInput
                onEdited: v => root.pinInput = v
                onAccepted: {
                    root.bt.respond(root.pinInput);
                    root.pinInput = "";
                }
            }

            RowLayout {
                visible: promptBox.kind !== "display"
                spacing: 6

                PanelButton {
                    text: promptBox.kind === "pin" || promptBox.kind === "passkey" ? "Enviar"
                        : promptBox.kind === "authorize" ? "Permitir"
                        : "Confirmar"
                    onClicked: {
                        const typed = promptBox.kind === "pin" || promptBox.kind === "passkey";
                        root.bt.respond(typed ? root.pinInput : "yes");
                        root.pinInput = "";
                    }
                }

                PanelButton {
                    text: "Recusar"
                    accent: Theme.colors.muted
                    onClicked: {
                        const typed = promptBox.kind === "pin" || promptBox.kind === "passkey";
                        root.bt.respond(typed ? "" : "no");
                        root.pinInput = "";
                    }
                }
            }
        }
    }

    Text {
        visible: !root.bt.powered
        text: "Bluetooth desligado"
        color: Theme.colors.muted
        font.family: Typo.family
        font.pixelSize: Typo.size.small
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.bt.powered
        spacing: 2

        PanelTitle {
            Layout.bottomMargin: 4
            text: "DISPOSITIVOS"
        }

        Text {
            visible: root.bt.pairedDevices.length === 0
            text: "Nenhum dispositivo pareado"
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Repeater {
            model: root.bt.pairedDevices

            delegate: ColumnLayout {
                id: paired

                required property var modelData
                readonly property var d: modelData
                readonly property bool isExpanded: root.expanded === d.address
                readonly property var audio: root.bt.audioCards[d.address] ?? null

                Layout.fillWidth: true
                spacing: 0

                DeviceRow {
                    Layout.fillWidth: true
                    icon: root.bt.deviceIcon(paired.d)
                    name: root.bt.deviceName(paired.d)
                    status: root.statusText(paired.d)
                    highlighted: paired.d.connected
                    open: paired.isExpanded
                    onClicked: root.expanded = paired.isExpanded ? "" : paired.d.address
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 6
                    Layout.bottomMargin: 8
                    visible: paired.isExpanded || root.bt.errorAddress === paired.d.address
                    spacing: 10

                    PanelError {
                        visible: root.bt.errorAddress === paired.d.address
                        text: root.bt.errorText
                    }

                    RowLayout {
                        visible: paired.isExpanded
                        spacing: 6

                        PanelButton {
                            text: paired.d.connected ? "Desconectar" : "Conectar"
                            accent: paired.d.connected ? Theme.colors.muted : Theme.colors.primary
                            onClicked: {
                                if (paired.d.connected)
                                    paired.d.disconnect();
                                else
                                    root.bt.connectDevice(paired.d);
                            }
                        }

                        PanelButton {
                            text: "Esquecer"
                            accent: Theme.colors.error
                            onClicked: {
                                root.expanded = "";
                                paired.d.forget();
                            }
                        }
                    }

                    PanelChips {
                        visible: paired.isExpanded && paired.d.connected && paired.audio !== null
                            && paired.audio.profiles.length > 1
                        label: "Áudio  (Microfone = qualidade de ligação)"
                        options: paired.audio ? paired.audio.profiles.map(p => ({ value: p.name, label: p.label })) : []
                        value: paired.audio ? paired.audio.active : ""
                        onPicked: v => root.bt.setProfile(paired.d.address, v)
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.bt.powered
        spacing: 2

        PanelTitle {
            Layout.bottomMargin: 4
            text: "POR PERTO"
        }

        Text {
            visible: root.bt.newDevices.length === 0
            text: root.bt.adapter !== null && root.bt.adapter.discovering
                ? "Procurando… (coloque o dispositivo em modo de pareamento)"
                : "Clique em 󰑐 para procurar"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Flickable {
            id: newScroll

            Layout.fillWidth: true
            visible: root.bt.newDevices.length > 0
            implicitHeight: Math.min(newColumn.implicitHeight, 260)
            contentHeight: newColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: newColumn

                width: newScroll.width
                spacing: 2

                Repeater {
                    model: root.bt.newDevices

                    delegate: ColumnLayout {
                        id: fresh

                        required property var modelData
                        readonly property var d: modelData

                        Layout.fillWidth: true
                        spacing: 0

                        DeviceRow {
                            Layout.fillWidth: true
                            icon: root.bt.deviceIcon(fresh.d)
                            name: root.bt.deviceName(fresh.d)
                            status: fresh.d.pairing ? "pareando…" : "clique para parear"
                            busy: fresh.d.pairing
                            onClicked: {
                                if (!fresh.d.pairing)
                                    root.bt.pairDevice(fresh.d);
                            }
                        }

                        PanelError {
                            Layout.leftMargin: 12
                            Layout.bottomMargin: 6
                            visible: root.bt.errorAddress === fresh.d.address
                            text: root.bt.errorText
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row

        property string icon
        property string name
        property string status
        property bool highlighted: false
        property bool open: false
        property bool busy: false
        signal clicked

        implicitHeight: 44
        radius: Sizes.radius.normal
        color: highlighted ? Theme.selected
             : rowMouse.containsMouse || open ? Theme.hover
             : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                text: row.icon
                color: row.highlighted ? Theme.colors.secondary : Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.large
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: row.name
                    elide: Text.ElideRight
                    color: Theme.colors.text
                    font.family: Typo.family
                    font.pixelSize: Typo.size.normal - 1
                    font.weight: row.highlighted ? Typo.weight.semibold : Typo.weight.regular
                }

                Text {
                    text: row.status
                    color: row.busy ? Theme.colors.warning : Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small - 1
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
