import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

Row {
    id: root

    Layout.alignment: Qt.AlignVCenter

    spacing: Sizes.spacing.normal

    Repeater {
        model: Hyprland.workspaces.values

        Rectangle {
            id: workspace

            required property var modelData

            readonly property bool isActive: modelData.focused

            implicitWidth: workspaceText.implicitWidth + 12
            implicitHeight: Sizes.item.size

            radius: Sizes.radius.normal

            color: isActive
                ? Theme.colors.secondary
                : Theme.colors.surface

            Text {
                id: workspaceText

                anchors.centerIn: parent

                text: workspace.modelData.id

                color: workspace.isActive
                    ? Theme.colors.background
                    : Theme.colors.foreground

                font {
                    family: Typo.family.default
                    pixelSize: Typo.size.normal
                    weight: Typo.weight.medium
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: workspace.modelData.activate()
            }
        }
    }
}
