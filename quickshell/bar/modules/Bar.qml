import Quickshell
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import qs.config

PanelWindow {
    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: Sizes.bar.height
    color: Theme.colors.background

    Item {
        anchors.fill: parent

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Sizes.bar.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.spacing.normal

            Workspaces {}
        }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Sizes.bar.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.spacing.normal

            Tray {}
            Ram {}
            Cpu {}
        }
    }
}
