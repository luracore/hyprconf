import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

PanelSurface {
    id: root

    required property var cava       // o módulo do cava: player, cor, capa

    readonly property MprisPlayer player: cava.player
    readonly property color accent: cava.shownColor
    readonly property var players: Mpris.players.values

    implicitWidth: 400

    // "3:07", "1:02:03"
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        const mm = h > 0 ? String(m).padStart(2, "0") : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + String(r).padStart(2, "0");
    }

    // a posição não se atualiza sozinha: relê a cada segundo enquanto toca
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    onActiveChanged: {
        if (active && player)
            player.positionChanged();
    }

    Text {
        visible: root.player === null
        text: "Nada tocando"
        color: Theme.colors.muted
        font.family: Typo.family
        font.pixelSize: Typo.size.small
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.player !== null
        spacing: 14

        ClippingRectangle {
            implicitWidth: 96
            implicitHeight: 96
            radius: Sizes.radius.normal
            color: Qt.alpha(root.accent, 0.18)

            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: root.cava.sourceGlyph
                color: root.accent
                font.family: Typo.family
                font.pixelSize: 40
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.cava.artFile !== "" ? root.cava.artFile : (root.player?.trackArtUrl ?? "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 192
                sourceSize.height: 192
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Sem título"
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.normal + 1
                font.weight: Typo.weight.semibold
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: root.accent
                font.family: Typo.family
                font.pixelSize: Typo.size.small + 1
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                elide: Text.ElideRight
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }
        }
    }

    ColumnLayout {
        id: progress

        Layout.fillWidth: true
        visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
        spacing: 2

        property real dragging: -1      // fração escolhida enquanto arrasta
        readonly property real length: root.player?.length ?? 0
        readonly property real shown: dragging >= 0 ? dragging * length : (root.player?.position ?? 0)

        PanelSlider {
            Layout.fillWidth: true
            enabled: root.player !== null && root.player.canSeek
            accent: root.accent
            wheelEnabled: false
            value: progress.length > 0 ? progress.shown / progress.length : 0
            onMoved: v => progress.dragging = v
            onReleased: {
                if (progress.dragging >= 0 && root.player)
                    root.player.position = progress.dragging * progress.length;
                progress.dragging = -1;
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.time(progress.shown)
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small - 1
                font.features: { "tnum": 1 }
            }

            Text {
                text: root.time(progress.length)
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small - 1
                font.features: { "tnum": 1 }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: root.player !== null
        spacing: 10

        ControlButton {
            visible: root.player?.shuffleSupported ?? false
            icon: root.player?.shuffle ? "󰒝" : "󰒞"
            on: root.player?.shuffle ?? false
            onClicked: root.player.shuffle = !root.player.shuffle
        }

        ControlButton {
            icon: "󰒮"
            enabledState: root.player?.canGoPrevious ?? false
            onClicked: root.player.previous()
        }

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: 24
            color: playMouse.containsMouse ? Qt.lighter(root.accent, 1.12) : root.accent
            opacity: root.player?.canTogglePlaying ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? "󰏤" : "󰐊"
                color: Theme.colors.background
                font.family: Typo.family
                font.pixelSize: 26
            }

            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.player?.canTogglePlaying)
                        root.player.togglePlaying();
                }
            }
        }

        ControlButton {
            icon: "󰒭"
            enabledState: root.player?.canGoNext ?? false
            onClicked: root.player.next()
        }

        // repetir: nada -> a lista -> a música
        ControlButton {
            visible: root.player?.loopSupported ?? false
            icon: root.player?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
            on: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
            onClicked: {
                const state = root.player.loopState;
                root.player.loopState = state === MprisLoopState.None ? MprisLoopState.Playlist
                    : state === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
        }
    }

    PanelDivider { visible: root.player !== null }

    RowLayout {
        Layout.fillWidth: true
        visible: root.player !== null
        spacing: 10

        Text {
            text: root.cava.glyphFor((root.player?.desktopEntry ?? "") + " " + (root.player?.identity ?? ""))
            color: root.accent
            font.family: Typo.family
            font.pixelSize: Typo.size.large
        }

        Text {
            Layout.fillWidth: true
            text: root.player?.identity ?? ""
            elide: Text.ElideRight
            color: Theme.colors.text
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }
    }

    PanelChips {
        Layout.fillWidth: true
        visible: root.players.length > 1
        label: "Controlar"
        accent: root.accent
        options: root.players.map(p => ({
            value: p.dbusName,
            label: root.cava.glyphFor(p.desktopEntry + " " + p.identity) + "  " + p.identity + (p.isPlaying ? "  󰐊" : "")
        }))
        value: root.player?.dbusName ?? ""
        onPicked: v => root.cava.choosePlayer(v)
    }

    // "on": aleatório/repetir ligados
    component ControlButton: Rectangle {
        id: control

        property string icon
        property bool on: false
        property bool enabledState: true
        signal clicked

        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        opacity: enabledState ? 1 : 0.35
        color: on ? Qt.alpha(root.accent, 0.2) : controlMouse.containsMouse && enabledState ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            text: control.icon
            color: control.on ? root.accent : Theme.colors.text
            font.family: Typo.family
            font.pixelSize: Typo.size.large + 2
        }

        MouseArea {
            id: controlMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: control.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (control.enabledState)
                    control.clicked();
            }
        }
    }
}
