import QtQuick

import qs.config

// Chave liga/desliga.
Rectangle {
    id: toggleSwitch

    property bool checked
    signal toggled

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.colors.info : Theme.colors.surface
    border.width: 1
    border.color: checked ? Theme.colors.info : Theme.colors.outline

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: toggleSwitch.checked ? parent.width - width - 3 : 3
        color: toggleSwitch.checked ? Theme.colors.background : Theme.colors.muted
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleSwitch.toggled()
    }
}
