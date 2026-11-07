import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import qs.config

RowLayout {
    id: root

    Layout.alignment: Qt.AlignVCenter

    spacing: Sizes.spacing.normal

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: item

            required property var modelData

            implicitWidth: Sizes.item.size
            implicitHeight: Sizes.item.size

            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: Sizes.radius.normal

                color: mouseArea.containsMouse
                    ? Theme.colors.surface
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
                        item.modelData.activate()
                    } else if (event.button === Qt.MiddleButton) {
                        item.modelData.secondaryActivate()
                    } else if (event.button === Qt.RightButton && item.modelData.hasMenu) {
                        const position = item.mapToItem(null, event.x, event.y)
                        item.modelData.display(QsWindow.window, position.x, position.y)
                    }

                    event.accepted = true
                }
            }
        }
    }
}
