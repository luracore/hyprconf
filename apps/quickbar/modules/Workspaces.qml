import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// grupo de workspaces: um container "surface" com quadrados dentro
Rectangle {
    id: root

    property string accent: "secondary"
    readonly property color accentColor: Theme.colors[accent] ?? Theme.colors.secondary
    readonly property color onAccentColor:
        Theme.colors["on" + accent.charAt(0).toUpperCase() + accent.slice(1)] ?? Theme.colors.background

    readonly property int pad: Sizes.module.groupPadding
    readonly property int cell: Sizes.module.height - 2 * pad

    Layout.alignment: Qt.AlignVCenter
    implicitHeight: Sizes.module.height
    implicitWidth: row.implicitWidth + 2 * pad

    radius: Sizes.module.radius
    color: Theme.colors.surface

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.pad

        Repeater {
            // sem workspaces especiais (id negativo)
            model: Hyprland.workspaces.values.filter(w => w.id > 0)

            Rectangle {
                id: workspace

                required property var modelData
                readonly property bool isActive: modelData.focused

                implicitWidth: Math.max(root.cell, workspaceText.implicitWidth + 12)
                implicitHeight: root.cell
                radius: Math.max(0, Sizes.module.radius - 1)

                color: isActive ? root.accentColor
                     : mouse.containsMouse ? Qt.alpha(root.accentColor, 0.2)
                     : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: workspaceText
                    anchors.centerIn: parent
                    text: workspace.modelData.name || workspace.modelData.id
                    color: workspace.isActive ? root.onAccentColor : Theme.colors.text
                    font.family: Typo.family
                    font.pixelSize: Typo.size.normal - 1
                    font.weight: Typo.weight.semibold
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspace.modelData.activate()
                }
            }
        }
    }
}
