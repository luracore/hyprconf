import Quickshell
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
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
            spacing: Sizes.module.gap

            DistroButton { powerMenu: power }
            Workspaces {}
            Cava {}
        }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Sizes.bar.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.module.gap

            Tray {}
            Network {}
            Volume {}
            Brightness {}
            Ram {}
            Cpu {}

            BarButton {
                icon: notifs.dnd ? "󰂛" : "󰂚"
                label: notifs.count > 0 ? String(notifs.count) : ""
                accent: notifs.dnd ? "warning" : "success"
                active: notifs.centerOpen
                onClicked: notifs.centerOpen = !notifs.centerOpen
            }
        }

        Notifications { id: notifs }
        PowerMenu { id: power }
    }
}
