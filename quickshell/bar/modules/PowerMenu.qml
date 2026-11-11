import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

// Tela de energia: bloquear, suspender, sair, reiniciar e desligar.
// Aberta pelo botão da distro na barra ou por IPC:
//   quickshell ipc --path ~/hyprconf/quickshell/bar call power toggle
//
// Teclado: h/l ou ←/→ (ou Tab) escolhem, Enter executa, Esc fecha.
// Sair, reiniciar e desligar pedem confirmação (Enter de novo).
Scope {
    id: root

    property bool open: false

    property int selected: 0
    property int confirming: -1          // índice aguardando confirmação

    readonly property var actions: [
        { name: "Bloquear",  icon: "󰌾", accent: "primary",   confirm: false,
          command: ["sh", "-c", "pidof hyprlock || hyprlock"] },
        { name: "Suspender", icon: "󰤄", accent: "info",      confirm: false,
          command: ["systemctl", "suspend"] },
        { name: "Sair",      icon: "󰍃", accent: "warning",   confirm: true,
          command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { name: "Reiniciar", icon: "󰜉", accent: "secondary", confirm: true,
          command: ["systemctl", "reboot"] },
        { name: "Desligar",  icon: "󰐥", accent: "error",     confirm: true,
          command: ["systemctl", "poweroff"] }
    ]

    function show() {
        selected = 0;
        confirming = -1;
        uptimeFile.reload();
        open = true;
    }

    function hide() {
        open = false;
        confirming = -1;
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    function move(step) {
        confirming = -1;
        selected = (selected + step + actions.length) % actions.length;
    }

    function activate(index) {
        const action = actions[index];
        selected = index;

        if (action.confirm && confirming !== index) {
            confirming = index;
            return;
        }

        hide();
        Quickshell.execDetached(action.command);
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }

    // "ligado há ..."
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }

    readonly property string uptime: {
        const seconds = Math.floor(parseFloat(uptimeFile.text().split(" ")[0]) || 0);
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        const parts = [];
        if (days > 0)
            parts.push(days + "d");
        if (hours > 0)
            parts.push(hours + "h");
        parts.push(minutes + "min");
        return parts.join(" ");
    }

    PanelWindow {
        id: window

        // continua visível até o fade de saída terminar
        visible: root.open || content.opacity > 0

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-power"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        color: "transparent"

        // fundo escurecido; clicar fora dos botões fecha
        Rectangle {
            anchors.fill: parent
            color: Theme.colors.background
            opacity: root.open ? 0.7 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Item {
            id: content

            anchors.fill: parent
            focus: root.open

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_H:
                case Qt.Key_Left:
                case Qt.Key_Backtab:
                    root.move(-1);
                    break;
                case Qt.Key_L:
                case Qt.Key_Right:
                case Qt.Key_Tab:
                    root.move(1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.activate(root.selected);
                    break;
                case Qt.Key_Escape:
                case Qt.Key_Q:
                    if (root.confirming >= 0)
                        root.confirming = -1;
                    else
                        root.hide();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 36

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Até logo, " + Quickshell.env("USER")
                        color: Theme.colors.text
                        font.family: Typo.family
                        font.pixelSize: 28
                        font.weight: Typo.weight.semibold
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "ligado há " + root.uptime
                        color: Theme.colors.muted
                        font.family: Typo.family
                        font.pixelSize: Typo.size.normal
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20

                    Repeater {
                        model: root.actions

                        delegate: Rectangle {
                            id: card

                            required property var modelData
                            required property int index

                            readonly property bool isSelected: index === root.selected
                            readonly property bool isConfirming: index === root.confirming
                            readonly property color accentColor:
                                Theme.colors[modelData.accent] ?? Theme.colors.primary

                            Layout.preferredWidth: 136
                            Layout.preferredHeight: 148

                            radius: 20
                            color: isConfirming ? Qt.alpha(Theme.colors.error, 0.18)
                                 : isSelected ? Qt.alpha(accentColor, 0.14)
                                 : Theme.colors.surface
                            border.width: isSelected || isConfirming ? 2 : 1
                            border.color: isConfirming ? Theme.colors.error
                                        : isSelected ? accentColor
                                        : Qt.alpha(Theme.colors.outline, 0.6)

                            scale: isSelected ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 14

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: card.modelData.icon
                                    color: card.isConfirming ? Theme.colors.error
                                         : card.isSelected ? card.accentColor
                                         : Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: 44
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: card.isConfirming ? "Confirmar?" : card.modelData.name
                                    color: card.isConfirming ? Theme.colors.error : Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal
                                    font.weight: Typo.weight.semibold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    if (root.selected !== card.index)
                                        root.move(card.index - root.selected);
                                }
                                onClicked: root.activate(card.index)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.confirming >= 0
                        ? "Enter ou clique de novo para " + root.actions[root.confirming].name.toLowerCase()
                          + "  ·  Esc cancela"
                        : "h/l escolhe  ·  Enter confirma  ·  Esc fecha"
                    color: root.confirming >= 0 ? Theme.colors.error : Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small
                }
            }
        }
    }
}
