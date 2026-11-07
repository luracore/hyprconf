import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.themes

Row {
  id: root

  Layout.alignment: Qt.AlignVCenter

  spacing: Sizes.spacing

  Repeater {
    model: Hyprland.workspaces.values

    Rectangle {
      id: workspace

      required property var modelData

      readonly property bool isActive: modelData.focused

      implicitWidth: workspaceText.implicitWidth + 12
      implicitHeight: Sizes.itemSize

      radius: Sizes.radius

      color: isActive
      ? Theme.active.secondary
      : Theme.active.surface

      Text {
        id: workspaceText
        anchors.centerIn: parent

        text: workspace.modelData.id

        color: workspace.isActive
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
        cursorShape: Qt.PointingHandCursor
        onClicked: workspace.modelData.activate()
      }
    }
  }
}
