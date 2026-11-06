import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.themes

Row {
  Layout.fillHeight: true
  spacing: Sizes.spacing

  Repeater {
    model: Hyprland.workspaces.values

    Rectangle {
      required property var modelData

      property bool isActive:
      Hyprland.focusedWorkspace?.id === modelData.id

      implicitWidth: workspaceText.implicitWidth + 12
      height: Sizes.barItemSize

      anchors.verticalCenter: parent.verticalCenter

      radius: Sizes.radius

      color: isActive
      ? Theme.active.secondary
      : Theme.active.surface

      Text {
        id: workspaceText
        anchors.centerIn: parent

        text: modelData.id

        color: isActive
        ? Theme.active.background
        : Theme.active.foreground

        font {
          family: Typo.family
          pixelSize: Typo.normal
          weight: Typo.weight
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: modelData.activate()
      }
    }
  }
}
