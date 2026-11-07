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

  Item {
    anchors.fill: parent

    RowLayout {
      anchors.left: parent.left
      anchors.leftMargin: Sizes.barPadding
      anchors.verticalCenter: parent.verticalCenter
      spacing: Sizes.spacing

      Workspaces {}
    }

    Clock {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
    }

    RowLayout {
      anchors.right: parent.right
      anchors.rightMargin: Sizes.barPadding
      anchors.verticalCenter: parent.verticalCenter
      spacing: Sizes.spacing

      Ram {}
      Cpu {}
    }
  }
}
