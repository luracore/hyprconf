import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Escolha entre poucas opções: options = [{ value, label }].
ColumnLayout {
    id: chips

    property string label
    property var options: []
    property string value
    property color accent: Theme.colors.primary
    signal picked(string value)

    spacing: 4

    Text {
        text: chips.label
        color: Theme.colors.muted
        font.family: Typo.family
        font.pixelSize: Typo.size.small - 1
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: chips.options

            delegate: Rectangle {
                id: chip

                required property var modelData
                readonly property bool selected: modelData.value === chips.value

                width: chipText.implicitWidth + 20
                height: 28
                radius: Sizes.radius.normal
                color: selected ? Qt.alpha(chips.accent, 0.2)
                     : chipMouse.containsMouse ? Theme.hover : Theme.colors.surface
                border.width: 1
                border.color: selected ? chips.accent : "transparent"

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.selected ? chips.accent : Theme.colors.text
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chips.picked(chip.modelData.value)
                }
            }
        }
    }
}
