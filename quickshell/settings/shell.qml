//@ pragma IconTheme Adwaita
// Configurações: atalhos para onde se mexe no hyprconf (pastas, arquivos de
// configuração e apps). Pastas abrem no explorador e arquivos no editor
// padrão (~/hyprconf/defaults.conf, via apps/hyprconf-run).
//
// Setas ou h/j/k/l escolhem, Enter abre, Esc fecha.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "config/Typo.js" as Typo
import qs.config

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    readonly property string repo: Quickshell.env("HOME") + "/hyprconf"
    readonly property string run: repo + "/apps/hyprconf-run"
    readonly property int columns: 5

    readonly property var items: [
        { icon: "󰸉", title: "Wallpapers", desc: "imagens de fundo",
          cmd: [run, "files", repo + "/Wallpapers"] },
        { icon: "󰏘", title: "Temas", desc: "temas de cores",
          cmd: [run, "files", repo + "/Themes"] },
        { icon: "󰋩", title: "Seletor", desc: "escolher wallpaper e tema",
          cmd: ["quickshell", "--path", repo + "/quickshell/wallpaper-picker/shell.qml"] },
        { icon: "󰌌", title: "Atalhos", desc: "as teclas do Hyprland",
          cmd: [run, "editor", repo + "/hypr/config/binds.lua"] },
        { icon: "󰀻", title: "Programas padrão", desc: "terminal, editor…",
          cmd: [run, "editor", repo + "/defaults.conf"] },
        { icon: "󰏗", title: "Pacotes", desc: "instalar e remover",
          cmd: ["sh", "-c", "exec foot --app-id=hyprconf-pacotes --title=Pacotes -o colors-dark.alpha=1 \"$HOME/hyprconf/apps/hyprconf-pacotes\""] },
        { icon: "󰍹", title: "Monitores", desc: "resolução e escala",
          cmd: [run, "editor", repo + "/hypr/config/monitor.lua"] },
        { icon: "󰃣", title: "Aparência", desc: "bordas e espaços",
          cmd: [run, "editor", repo + "/hypr/config/appearance.lua"] },
        { icon: "󰐥", title: "Inicialização", desc: "o que abre com o Hyprland",
          cmd: [run, "editor", repo + "/hypr/config/startup.lua"] },
        { icon: "󰚰", title: "Atualizar", desc: "a versão nova do setup",
          cmd: ["sh", "-c", "exec foot --app-id=hyprconf-atualizar --title=Atualizar -o colors-dark.alpha=1 sh -c '\"$HOME/hyprconf/update.sh\"; echo; echo Enter fecha; read x'"] }
    ]

    property int selected: 0

    function open(index) {
        Quickshell.execDetached(items[index].cmd);
        Qt.quit();
    }

    function move(dx, dy) {
        const col = selected % columns;
        const row = Math.floor(selected / columns);
        const rows = Math.ceil(items.length / columns);
        const next = ((row + dy + rows) % rows) * columns + (col + dx + columns) % columns;
        if (next < items.length)
            selected = next;
    }

    // fundo escurecido; clicar fora fecha
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.background
        opacity: 0.7

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Left: case Qt.Key_H: root.move(-1, 0); break;
            case Qt.Key_Right: case Qt.Key_L: root.move(1, 0); break;
            case Qt.Key_Up: case Qt.Key_K: root.move(0, -1); break;
            case Qt.Key_Down: case Qt.Key_J: root.move(0, 1); break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: root.open(root.selected); break;
            case Qt.Key_Escape: case Qt.Key_Q: Qt.quit(); break;
            default: return;
            }
            event.accepted = true;
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 24

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Configurações"
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: 28
                font.weight: Typo.weight.semibold
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                rowSpacing: 14
                columnSpacing: 14

                Repeater {
                    model: root.items

                    delegate: Rectangle {
                        id: card

                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.selected

                        Layout.preferredWidth: 250
                        Layout.preferredHeight: 84
                        radius: 16
                        color: current ? Qt.alpha(Theme.colors.primary, 0.14) : Theme.colors.surface
                        border.width: current ? 2 : 1
                        border.color: current ? Theme.colors.primary : Qt.alpha(Theme.colors.outline, 0.6)
                        scale: current ? 1.03 : 1

                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 16
                            spacing: 16

                            Text {
                                text: card.modelData.icon
                                color: card.current ? Theme.colors.primary : Theme.colors.text
                                font.family: Typo.family
                                font.pixelSize: 30
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.title
                                    elide: Text.ElideRight
                                    color: Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal + 1
                                    font.weight: Typo.weight.semibold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.desc
                                    elide: Text.ElideRight
                                    color: Theme.colors.muted
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.small
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = card.index
                            onClicked: root.open(card.index)
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Enter abre  ·  Esc fecha"
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }
        }
    }
}
