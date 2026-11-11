import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Campo de texto com rótulo. Digitar emite edited(valor); o valor exibido
// segue "value" (inclusive quando ele é limpo de fora).
ColumnLayout {
    id: field

    property string label
    property string value
    property string placeholder
    property bool password: false
    property bool revealed: false
    signal edited(string value)
    signal accepted

    spacing: 4

    Text {
        text: field.label
        color: Theme.colors.muted
        font.family: Typo.family
        font.pixelSize: Typo.size.small - 1
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: Sizes.radius.normal
        color: Theme.colors.surface
        border.width: input.activeFocus ? 1 : 0
        border.color: Theme.colors.primary

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter

            text: field.value
            echoMode: field.password && !field.revealed ? TextInput.Password : TextInput.Normal
            color: Theme.colors.text
            selectionColor: Qt.alpha(Theme.colors.primary, 0.4)
            font.family: Typo.family
            font.pixelSize: Typo.size.normal - 1
            clip: true

            onTextEdited: field.edited(text)
            onAccepted: field.accepted()

            // digitar desfaz a ligação com field.value; mantém em sincronia
            Connections {
                target: field
                function onValueChanged() {
                    if (input.text !== field.value)
                        input.text = field.value;
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: field.placeholder
                color: Qt.alpha(Theme.colors.muted, 0.7)
                font: input.font
            }
        }
    }
}
