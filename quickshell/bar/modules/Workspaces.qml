import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../themes"

RowLayout {
    spacing: Theme.active.spacing

    Repeater {
        model: Hyprland.workspaces.values

        Text {
            required property var modelData

            property bool isActive:
                Hyprland.focusedWorkspace?.id === modelData.id

            text: modelData.id

            color: isActive
                ? Theme.active.active
                : Theme.active.muted

            font {
                family: Theme.active.fontFamily
                pixelSize: Theme.active.fontSize
                bold: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
            }
        }
    }
}
