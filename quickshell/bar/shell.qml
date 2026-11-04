import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 30
  color: "#1a1b26"

  RowLayout {
    anchors.fill: parent
    anchors.margins: 8

    Repeater {
      model: Hyprland.workspaces.values

      Text {
        required property var modelData

        property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id

        text: modelData.id
        color: isActive ? "#0db9d7" : "#7aa2f7"
        font {
          pixelSize: 14
          bold: true
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            Hyprland.dispatch(
              `hl.dsp.focus({ workspace = ${index + 1} })`
            )
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
    }
  }
}
