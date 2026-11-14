import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

PanelSurface {
    id: root

    readonly property var devices: Pipewire.nodes.values.filter(n => !n.isStream && n.audio !== null)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)
    // isSink deixa o cava de fora (ele só escuta)
    readonly property var apps: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio !== null)

    // necessário para o PipeWire expor volume/mudo dos nós
    PwObjectTracker {
        objects: root.devices.concat(root.apps)
    }

    implicitWidth: 380

    AudioSection {
        Layout.fillWidth: true
        title: "SAÍDA"
        node: Pipewire.defaultAudioSink
        devices: root.sinks
        icons: ["󰝟", "󰕿", "󰖀", "󰕾"]
        emptyText: "Nenhum dispositivo de saída"
        onSelect: node => Pipewire.preferredDefaultAudioSink = node
    }

    PanelDivider {}

    AudioSection {
        Layout.fillWidth: true
        title: "ENTRADA"
        node: Pipewire.defaultAudioSource
        devices: root.sources
        icons: ["󰍭", "󰍬", "󰍬", "󰍬"]
        emptyText: "Nenhum dispositivo de entrada"
        onSelect: node => Pipewire.preferredDefaultAudioSource = node
    }

    PanelDivider {}

    // o WirePlumber guarda o volume de cada app e reaplica depois

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        PanelTitle { text: "APLICATIVOS" }

        Repeater {
            model: root.apps

            delegate: AppRow {}
        }

        Text {
            visible: root.apps.length === 0
            text: "Nenhum app tocando som"
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }
    }

    component AppRow: RowLayout {
        id: app

        required property PwNode modelData
        readonly property var props: modelData.properties ?? {}
        readonly property string name: props["application.name"] || modelData.description || modelData.name
        readonly property string media: (props["media.name"] ?? "") !== name ? (props["media.name"] ?? "") : ""
        readonly property bool ready: modelData.audio !== null
        readonly property bool muted: ready && modelData.audio.muted
        readonly property real volume: ready ? modelData.audio.volume : 0

        function iconPath() {
            const binary = props["application.process.binary"] ?? "";
            const entry = DesktopEntries.heuristicLookup(name) ?? DesktopEntries.heuristicLookup(binary);
            for (const icon of [props["application.icon-name"], entry?.icon, binary, name.toLowerCase()]) {
                if (icon && Quickshell.iconPath(icon, true) !== "")
                    return Quickshell.iconPath(icon);
            }
            return Quickshell.iconPath("audio-x-generic");
        }

        function setVolume(v) {
            if (!ready)
                return;
            modelData.audio.muted = false;
            modelData.audio.volume = Math.max(0, Math.min(1, v));
        }

        Layout.fillWidth: true
        spacing: 12

        IconImage {
            implicitSize: 28
            source: app.iconPath()
            asynchronous: true
            opacity: app.muted ? 0.35 : 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (app.ready)
                        app.modelData.audio.muted = !app.modelData.audio.muted;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: app.media !== "" ? app.name + "  ·  " + app.media : app.name
                elide: Text.ElideRight
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }

            PanelSlider {
                Layout.fillWidth: true
                accent: app.muted ? Theme.colors.muted : Theme.colors.tertiary
                value: app.muted ? 0 : app.volume
                onMoved: v => app.setVolume(v)
            }
        }

        Text {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: !app.ready ? "--" : app.muted ? "mudo" : Math.round(app.volume * 100) + "%"
            color: Theme.colors.text
            font.family: Typo.family
            font.pixelSize: Typo.size.normal - 1
            font.weight: Typo.weight.semibold
        }
    }

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

        PanelTitle { text: section.title }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: section.ready
            opacity: enabled ? 1 : 0.5

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

            PanelSlider {
                Layout.fillWidth: true
                accent: section.muted ? Theme.colors.muted : Theme.colors.tertiary
                value: section.muted ? 0 : section.volume
                onMoved: v => section.setVolume(v)
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
