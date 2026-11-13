import Quickshell.Io
import QtQuick

// Brilho da tela principal (a do notebook, se houver; senão, o primeiro
// monitor com DDC/CI). Sem brilho controlável, fica só o ícone.
//
// clique: painel de monitores · scroll: ±5% · atalhos (IPC up/down): ±10%
BarButton {
    id: root

    property var bar: null          // a janela da barra (Bar.qml): em qual monitor ela fica
    readonly property var control: displays.primary
    readonly property int brightness: control && control.ready ? control.brightness : -1
    readonly property int step: 5
    readonly property int keyStep: 10

    icon: control === null ? "󰍹" : brightness < 34 ? "󰃞" : brightness < 67 ? "󰃟" : "󰃠"
    label: control === null ? "" : brightness < 0 ? "--" : brightness + "%"
    labelTemplate: control === null ? "" : "100%"
    accent: "warning"

    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
    }
    onScrolled: steps => {
        if (control)
            control.step(steps * step);
    }

    Displays {
        id: displays

        // o painel foi criado na escala antiga e ficaria borrado: fecha e
        // abre de novo (dá um tempo para o monitor terminar de mudar)
        onGeometryChanged: {
            if (popup.visible) {
                popup.visible = false;
                reopen.restart();
            }
        }
    }

    Timer {
        id: reopen
        interval: 300
        onTriggered: root.togglePanel()
    }

    function togglePanel() {
        popup.visible = !popup.visible;
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        DisplayPanel {
            id: panel

            anchors.fill: parent
            displays: displays
            bar: root.bar
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call brightness up|down|set 50|togglePanel
    IpcHandler {
        target: "brightness"
        function up(): void { if (root.control) root.control.step(root.keyStep); }
        function down(): void { if (root.control) root.control.step(-root.keyStep); }
        function set(percent: int): void { if (root.control) root.control.set(percent); }
        function togglePanel(): void { root.togglePanel(); }
    }
}
