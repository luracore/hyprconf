import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Painel de áudio (aberto pelo módulo de volume): volume e dispositivo
// padrão de saída e de entrada.
Rectangle {
    id: root

    property bool active: true

    signal closeRequested

    readonly property var devices: Pipewire.nodes.values.filter(n => !n.isStream && n.audio !== null)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)

    // necessário para o PipeWire expor volume/mudo dos nós
    PwObjectTracker {
        objects: root.devices
    }

    implicitWidth: 380
    implicitHeight: layout.implicitHeight + 28

    color: Theme.colors.background
    radius: Sizes.radius.normal + 2
    border.width: 1
    border.color: Theme.colors.outline

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.active
        onActivated: root.closeRequested()
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        AudioSection {
            Layout.fillWidth: true
            title: "SAÍDA"
            node: Pipewire.defaultAudioSink
            devices: root.sinks
            icons: ["󰝟", "󰕿", "󰖀", "󰕾"]
            emptyText: "Nenhum dispositivo de saída"
            onSelect: node => Pipewire.preferredDefaultAudioSink = node
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Theme.colors.outline, 0.6)
        }

        AudioSection {
            Layout.fillWidth: true
            title: "ENTRADA"
            node: Pipewire.defaultAudioSource
            devices: root.sources
            icons: ["󰍭", "󰍬", "󰍬", "󰍬"]
            emptyText: "Nenhum dispositivo de entrada"
            onSelect: node => Pipewire.preferredDefaultAudioSource = node
        }
    }

    // ---- seção: título, slider do padrão e lista de dispositivos ---------

    component AudioSection: ColumnLayout {
        id: section

        property string title
        property PwNode node
        property var devices: []
        property var icons: []           // [mudo, baixo, médio, alto]
        property string emptyText

        signal select(PwNode node)

        readonly property bool ready: node !== null && node.audio !== null
        readonly property real volume: ready ? node.audio.volume : 0
        readonly property bool muted: ready ? node.audio.muted : false

        function nodeName(n) {
            return n ? (n.description || n.nickname || n.name) : "";
        }

        function setVolume(v) {
            if (!ready)
                return;
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }

        spacing: 10

        Text {
            text: section.title
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
            font.weight: Typo.weight.bold
            font.letterSpacing: 2
        }

        // volume do dispositivo padrão
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: section.ready
            opacity: enabled ? 1 : 0.5

            // botão de mudo
            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Sizes.radius.normal
                color: section.muted ? Qt.alpha(Theme.colors.error, 0.18)
                     : muteMouse.containsMouse ? Theme.hover : Theme.colors.surface

                Text {
                    anchors.centerIn: parent
                    text: section.muted ? section.icons[0]
                        : section.volume < 0.34 ? section.icons[1]
                        : section.volume < 0.67 ? section.icons[2]
                        : section.icons[3]
                    color: section.muted ? Theme.colors.error : Theme.colors.tertiary
                    font.family: Typo.family
                    font.pixelSize: Typo.size.large
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (section.ready)
                            section.node.audio.muted = !section.node.audio.muted;
                    }
                }
            }

            // slider
            Item {
                id: slider

                Layout.fillWidth: true
                implicitHeight: 20

                readonly property real shown: section.muted ? 0 : section.volume

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.colors.surface

                    Rectangle {
                        width: parent.width * slider.shown
                        height: parent.height
                        radius: parent.radius
                        color: section.muted ? Theme.colors.muted : Theme.colors.tertiary
                    }
                }

                Rectangle {
                    x: (slider.width - width) * slider.shown
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.colors.text
                    border.width: 3
                    border.color: section.muted ? Theme.colors.muted : Theme.colors.tertiary
                    scale: sliderMouse.pressed || sliderMouse.containsMouse ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function update(mouse) {
                        section.setVolume((mouse.x - 6) / slider.width);
                    }

                    onPressed: mouse => update(mouse)
                    onPositionChanged: mouse => {
                        if (pressed)
                            update(mouse);
                    }
                    onWheel: wheel => section.setVolume(section.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }

            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: !section.ready ? "--" : section.muted ? "mudo" : Math.round(section.volume * 100) + "%"
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.normal - 1
                font.weight: Typo.weight.semibold
            }
        }

        // dispositivos
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: section.devices

                delegate: Rectangle {
                    id: device

                    required property PwNode modelData
                    readonly property bool current: modelData === section.node

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Sizes.radius.normal
                    color: current ? Theme.selected : deviceMouse.containsMouse ? Theme.hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: device.current ? "󰄴" : "󰄰"
                            color: device.current ? Theme.colors.tertiary : Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.normal + 2
                        }

                        Text {
                            Layout.fillWidth: true
                            text: section.nodeName(device.modelData)
                            elide: Text.ElideRight
                            color: device.current ? Theme.colors.text : Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.normal - 1
                            font.weight: device.current ? Typo.weight.semibold : Typo.weight.regular
                        }
                    }

                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!device.current)
                                section.select(device.modelData);
                        }
                    }
                }
            }

            Text {
                visible: section.devices.length === 0
                text: section.emptyText
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }
        }
    }
}
