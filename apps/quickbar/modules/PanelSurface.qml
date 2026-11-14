import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import qs.config

// Com closesOnEscape false, o painel trata o Esc antes (ex.: fechar um
// formulário aberto) em onEscapePressed.
Rectangle {
    id: surface

    property bool active: true
    property bool closesOnEscape: true
    property int padding: 14
    property alias spacing: column.spacing
    default property alias content: column.data

    signal closeRequested
    signal escapePressed

    implicitHeight: column.implicitHeight + 2 * padding

    color: Theme.colors.background
    radius: Sizes.radius.normal + 2
    border.width: 1
    border.color: Theme.colors.outline

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: surface.active
        onActivated: {
            surface.escapePressed();
            if (surface.closesOnEscape)
                surface.closeRequested();
        }
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: surface.padding
        spacing: 14
    }
}
