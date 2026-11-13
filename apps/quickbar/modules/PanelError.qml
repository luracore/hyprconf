import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

// Mensagem de erro dos painéis da barra.
Text {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Theme.colors.error
    font.family: Typo.family
    font.pixelSize: Typo.size.small
}
