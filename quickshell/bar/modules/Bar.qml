import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.themes

PanelWindow {
  anchors.top: true
  anchors.left: true
  anchors.right: true

  implicitHeight: Sizes.barHeight
  color: Theme.active.background

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Sizes.barPadding
    anchors.rightMargin: Sizes.barPadding
    spacing: 0

    Workspaces {Layout.alignment: Qt.AlignVCenter}
    Item {Layout.fillWidth: true}
    Workspaces {Layout.alignment: Qt.AlignVCenter}
    Item {Layout.fillWidth: true}
    Workspaces {Layout.alignment: Qt.AlignVCenter}
  }
}
