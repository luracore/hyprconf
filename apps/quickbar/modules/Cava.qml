import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Colors.js" as Colors
import "../config/Typo.js" as Typo
import qs.config

Rectangle {
    id: root

    // cor do tema usada quando não há capa (ou followMedia = false)
    property string accent: "success"
    readonly property color themeAccent: Theme.colors[accent] ?? Theme.colors.success

    // pega a cor da capa do que está tocando (MPRIS)
    property bool followMedia: true

    readonly property color accentColor: artFile !== ""
        ? Colors.accentFromImage(
            Array.prototype.map.call(quantizer.colors, c => String(c)),
            Theme.colors,
            String(themeAccent))
        : themeAccent

    property color shownColor: accentColor
    Behavior on shownColor { ColorAnimation { duration: 400 } }

    // o escolhido no painel (enquanto existir e nenhum outro tocar no lugar
    // dele); senão, o primeiro tocando; senão, o primeiro da lista
    property string chosenPlayer: ""
    readonly property MprisPlayer player: {
        const list = Mpris.players.values
        const chosen = Array.prototype.find.call(list, p => p.dbusName === chosenPlayer)
        if (chosen && (chosen.isPlaying || !Array.prototype.some.call(list, p => p.isPlaying)))
            return chosen
        return Array.prototype.find.call(list, p => p.isPlaying) ?? list[0] ?? null
    }

    function choosePlayer(dbusName) {
        chosenPlayer = dbusName
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
        rescaleSize: 64
    }

    property int barWidth: 4
    property int barGap: 1
    property bool bordered: true

    property var values: []   // 0-100 por barra

    readonly property int pad: Sizes.module.groupPadding + 3

    // símbolo do app que está tocando: o player MPRIS tocando (é dele a cor da
    // capa) ou, sem ele, o primeiro app com som; sem som, a nota musical (o
    // bloco fica sempre, para o módulo não mudar de tamanho)
    readonly property string sourceGlyph: player && player.isPlaying
        ? glyphFor(player.desktopEntry + " " + player.identity)
        : sources.length > 0 ? glyphFor(sources[0].name + " " + sources[0].binary) : glyphFor("")
    readonly property int maxBarHeight: height - 2 * (Sizes.module.groupPadding + 2)

    visible: values.length > 0

    Layout.alignment: Qt.AlignVCenter
    implicitHeight: Sizes.module.height
    implicitWidth: height + row.implicitWidth + 2 * pad

    radius: Sizes.module.radius
    color: Theme.colors.surface
    border.width: bordered ? 1 : 0
    border.color: shownColor

    Rectangle {
        id: iconBlock

        width: root.height
        height: root.height
        radius: root.radius
        color: root.shownColor

        // lado direito reto, "colando" nas barras
        Rectangle {
            anchors.right: parent.right
            width: parent.radius
            height: parent.height
            color: parent.color
        }

        Text {
            anchors.centerIn: parent
            text: root.sourceGlyph
            color: Theme.colors.background
            font.family: Typo.family
            font.pixelSize: Typo.size.large + 2
        }
    }

    Row {
        id: row

        anchors.left: iconBlock.right
        anchors.leftMargin: root.pad
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
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]

        stdout: SplitParser {
            property string last: ""
            onRead: line => {
                if (line === last)
                    return;
                last = line;
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

    // Os fluxos de saída de áudio não pausados, pelo pactl: o PipeWire do
    // Quickshell não diz se um fluxo está pausado (o Spotify pausado, por
    // exemplo, continua com o fluxo aberto).

    property var sources: []        // [{ name, binary }], um por app

    // símbolo (Nerd Font) pelo nome do app; desconhecido = nota musical
    readonly property var glyphs: [
        [/spotify/i, "\u{F04C7}"],
        [/youtube/i, "\u{F05C3}"],
        [/firefox|librewolf|zen/i, "\u{F0239}"],
        [/chrom|brave|vivaldi/i, "\u{F02AF}"],
        [/discord|vesktop|webcord/i, "\u{F066F}"],
        [/steam/i, "\u{F04D3}"],
        [/vlc/i, "\u{F057C}"],
        [/mpv|celluloid|totem|haruna/i, "\u{F040C}"]
    ]

    function glyphFor(text) {
        return glyphs.find(g => g[0].test(text))?.[1] ?? "\u{F0386}";
    }

    Process {
        id: listStreams
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let streams = [];
                try {
                    streams = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const seen = {};
                const list = [];
                for (const stream of streams) {
                    const props = stream.properties ?? {};
                    // pausado, ou o próprio cava (que só escuta)
                    if (stream.corked || props["application.process.binary"] === "cava")
                        continue;
                    const name = props["application.name"] ?? props["application.process.binary"] ?? "Áudio";
                    if (seen[name])
                        continue;
                    seen[name] = true;
                    list.push({ name: name, binary: props["application.process.binary"] ?? "" });
                }
                root.sources = list;
            }
        }
    }

    Timer {
        id: refreshStreams
        interval: 150
        onTriggered: {
            listStreams.running = false;
            listStreams.running = true;
        }
    }

    // avisa quando um fluxo abre, fecha ou pausa
    Process {
        id: subscribe
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("sink-input"))
                    refreshStreams.restart();
            }
        }
        onRunningChanged: if (running) refreshStreams.restart()
    }

    Timer {
        interval: 3000
        repeat: true
        running: !subscribe.running
        onTriggered: subscribe.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.player?.canTogglePlaying)
                    root.player.togglePlaying()
            } else {
                root.togglePanel()
            }
        }
    }

    function togglePanel() {
        popup.visible = !popup.visible
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        MediaPanel {
            id: panel

            anchors.fill: parent
            cava: root
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call media togglePanel|playPause|next|previous
    IpcHandler {
        target: "media"
        function togglePanel(): void { root.togglePanel() }
        function playPause(): void { if (root.player?.canTogglePlaying) root.player.togglePlaying() }
        function next(): void { if (root.player?.canGoNext) root.player.next() }
        function previous(): void { if (root.player?.canGoPrevious) root.player.previous() }
    }
}
