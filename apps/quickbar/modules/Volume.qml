import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

BarButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property real step: 0.05

    // necessário para o PipeWire expor volume/mudo do nó
    PwObjectTracker {
        objects: [root.sink]
    }

    icon: muted ? "󰝟"
        : volume < 0.34 ? "󰕿"
        : volume < 0.67 ? "󰖀"
        : "󰕾"
    label: !ready ? "--" : muted ? "mudo" : Math.round(volume * 100) + "%"
    labelTemplate: "100%"
    accent: muted ? "error" : "tertiary"

    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
        else if (m.button === Qt.MiddleButton)
            root.toggleMute();
    }
    onScrolled: steps => root.setVolume(volume + steps * step)

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    function togglePanel() {
        popup.visible = !popup.visible;
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        AudioPanel {
            id: panel

            anchors.fill: parent
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call volume up|down|mute|set 50|togglePanel
    IpcHandler {
        target: "volume"
        function up(): void { root.setVolume(root.volume + root.step); }
        function down(): void { root.setVolume(root.volume - root.step); }
        function mute(): void { root.toggleMute(); }
        function set(percent: int): void { root.setVolume(percent / 100); }
        function togglePanel(): void { root.togglePanel(); }
    }
}
