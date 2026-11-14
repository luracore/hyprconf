import QtQuick

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

Rectangle {
    id: iconButton

    property string icon
    property bool spinning: false
    signal clicked

    implicitWidth: 28
    implicitHeight: 28
    radius: Sizes.radius.normal
    color: iconMouse.containsMouse ? Theme.hover : "transparent"

    Text {
        anchors.centerIn: parent
        text: iconButton.icon
        color: Theme.colors.text
        font.family: Typo.family
        font.pixelSize: Typo.size.normal + 2

        RotationAnimation on rotation {
            running: iconButton.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconButton.clicked()
    }
}
