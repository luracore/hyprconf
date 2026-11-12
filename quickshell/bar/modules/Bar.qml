import Quickshell
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

PanelWindow {
    id: barWindow

    // o shell.qml: escolhe em qual monitor a barra fica
    property var shell: null

    function setPreferredOutput(name) {
        shell.setPreferredOutput(name);
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: Sizes.bar.height
    color: Theme.colors.background

    Item {
        anchors.fill: parent

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Sizes.bar.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.module.gap

            DistroButton { powerMenu: power }
            // o cava antes dos workspaces: não anda quando um workspace abre ou fecha
            Cava {}
            Workspaces {}
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: rightRow

            // Os módulos da direita nunca passam por cima do relógio: se não
            // couberem no espaço até ele, ficam compactos (só ícone).
            readonly property real space: parent.width / 2 - clock.width / 2
                                          - Sizes.bar.padding - 2 * Sizes.module.gap
            property real fullWidth: 0      // largura com os textos (medida fora do modo compacto)
            readonly property bool compact: fullWidth > space

            onImplicitWidthChanged: {
                if (!compact)
                    fullWidth = implicitWidth;
            }

            anchors.right: parent.right
            anchors.rightMargin: Sizes.bar.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.module.gap

            Tray {}
            Network {}
            Bluetooth {}
            Volume { compact: rightRow.compact }
            Brightness { compact: rightRow.compact; bar: barWindow }
            System { compact: rightRow.compact }

            BarButton {
                compact: rightRow.compact
                icon: notifs.dnd ? "󰂛" : "󰂚"
                label: notifs.count > 0 ? String(notifs.count) : ""
                accent: notifs.dnd ? "warning" : "success"
                active: notifs.centerOpen
                onClicked: notifs.centerOpen = !notifs.centerOpen
            }
        }

        Notifications { id: notifs }
        PowerMenu { id: power }
    }
}
