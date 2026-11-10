import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/ThemeColors.js" as ThemeColors
import qs.config

// Visualizador de áudio: lê a saída raw do cava (config/cava.conf)
Rectangle {
    id: root

    // cor do tema usada quando não há capa (ou followMedia = false)
    property string accent: "success"
    readonly property color themeAccent: Theme.colors[accent] ?? Theme.colors.success

    // pega a cor da capa do que está tocando (MPRIS)
    property bool followMedia: true

    readonly property color accentColor: artFile !== ""
        ? ThemeColors.accentFromImage(
            Array.prototype.map.call(quantizer.colors, c => String(c)),
            Theme.colors,
            String(themeAccent))
        : themeAccent

    // a cor exibida anima até accentColor
    property color shownColor: accentColor
    Behavior on shownColor { ColorAnimation { duration: 400 } }

    // ---- mídia ----------------------------------------------------------

    // o primeiro player tocando; se nenhum estiver tocando, o primeiro da lista
    readonly property MprisPlayer player: {
        const list = Mpris.players.values
        return Array.prototype.find.call(list, p => p.isPlaying) ?? list[0] ?? null
    }
    readonly property string artUrl: followMedia && player ? player.trackArtUrl : ""

    // arquivo local da capa (o ColorQuantizer só lê arquivos locais)
    property string artFile: ""

    onArtUrlChanged: {
        if (artUrl === "") {
            artFile = ""
        } else if (artUrl.startsWith("file://") || artUrl.startsWith("/")) {
            artFile = artUrl
        } else {
            // http(s): baixa uma vez para o cache, nome = md5 da url
            const dest = Quickshell.cachePath("covers/" + Qt.md5(artUrl))
            download.dest = dest
            download.command = ["sh", "-c",
                'mkdir -p "$(dirname "$1")" && { [ -s "$1" ] || curl -sfL --max-time 10 -o "$1" "$2"; }',
                "sh", dest, artUrl]
            download.running = false
            download.running = true
        }
    }

    Process {
        id: download
        property string dest: ""
        onExited: code => {
            // só aplica se ainda for a capa atual
            if (code === 0 && dest === Quickshell.cachePath("covers/" + Qt.md5(root.artUrl)))
                root.artFile = "file://" + dest
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.artFile
        depth: 3          // 2^3 = 8 cores
        rescaleSize: 64   // reduz a capa antes de analisar
    }

    property int barWidth: 4
    property int barGap: 1
    property bool bordered: true

    property var values: []   // 0-100 por barra

    readonly property int pad: Sizes.module.groupPadding + 3
    readonly property int maxBarHeight: height - 2 * (Sizes.module.groupPadding + 2)

    // só aparece quando o cava está mandando dados
    visible: values.length > 0

    Layout.alignment: Qt.AlignVCenter
    implicitHeight: Sizes.module.height
    implicitWidth: row.implicitWidth + 2 * pad

    radius: Sizes.module.radius
    color: Theme.colors.surface
    border.width: bordered ? 1 : 0
    border.color: shownColor

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sizes.module.groupPadding + 2
        spacing: root.barGap

        Repeater {
            model: root.values.length

            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: root.barWidth
                // mínimo de 2px pra mostrar a "linha" em silêncio
                height: Math.max(2, root.maxBarHeight * (root.values[index] ?? 0) / 100)
                radius: 1
                color: root.shownColor
            }
        }
    }

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Quickshell.shellPath("config/cava.conf")]

        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                if (parts[parts.length - 1] === "")
                    parts.pop();
                root.values = parts.map(Number);
            }
        }

        onRunningChanged: if (!running) root.values = []
    }

    // se o cava não abrir ou cair (não instalado, PipeWire reiniciou...),
    // tenta de novo a cada 3s. Não dá pra depender do onExited: quando o
    // binário não existe o processo nem chega a iniciar e ele não dispara.
    Timer {
        interval: 3000
        repeat: true
        running: !cava.running
        onTriggered: cava.running = true
    }
}
