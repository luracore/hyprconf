import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import qs.config

// grupo do tray: container "surface" com os ícones
Rectangle {
    id: root

    // ícones substituídos por módulos da barra: nm-applet (Network; continua
    // rodando como agente de senhas) e blueman (Bluetooth)
    readonly property var hiddenIds: ["nm-applet", "blueman"]
    readonly property var items: SystemTray.items.values.filter(i => !hiddenIds.includes(i.id))

    readonly property int pad: Sizes.module.groupPadding
    readonly property int cell: Sizes.module.height - 2 * pad

    Layout.alignment: Qt.AlignVCenter
    visible: items.length > 0
    implicitHeight: Sizes.module.height
    implicitWidth: row.implicitWidth + 2 * pad

    radius: Sizes.module.radius
    color: Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.primary

    function openMenu(item) {
        if (!item.modelData.hasMenu)
            return

        menu.open(item.modelData.menu, item)
    }

    TrayMenu {
        id: menu
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.pad

    Repeater {
        model: root.items

        delegate: Item {
            id: item

            required property var modelData

            implicitWidth: root.cell
            implicitHeight: root.cell

            Rectangle {
                anchors.fill: parent
                radius: Math.max(0, Sizes.module.radius - 1)

                color: mouseArea.containsMouse
                    ? Theme.hover
                    : "transparent"
            }

            IconImage {
                anchors.centerIn: parent

                implicitSize: 16
                mipmap: true

                source: item.modelData.icon
            }

            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: event => {
                    if (event.button === Qt.LeftButton) {
                        if (item.modelData.onlyMenu && item.modelData.hasMenu)
                            root.openMenu(item)
                        else
                            item.modelData.activate()
                    } else if (event.button === Qt.MiddleButton) {
                        item.modelData.secondaryActivate()
                    } else if (event.button === Qt.RightButton) {
                        root.openMenu(item)
                    }

                    event.accepted = true
                }
            }
        }
    }
    }
}
