import QtQuick

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

Rectangle {
    id: button

    property string text
    property color accent: Theme.colors.primary
    property bool enabledState: true
    signal clicked

    implicitWidth: buttonText.implicitWidth + 24
    implicitHeight: 30
    radius: Sizes.radius.normal
    opacity: enabledState ? 1 : 0.45
    color: buttonMouse.containsMouse && enabledState ? Qt.alpha(accent, 0.28) : Qt.alpha(accent, 0.16)
    border.width: 1
    border.color: Qt.alpha(accent, 0.6)

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: button.text
        color: button.accent
        font.family: Typo.family
        font.pixelSize: Typo.size.small
        font.weight: Typo.weight.semibold
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: button.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (button.enabledState)
                button.clicked();
        }
    }
}
