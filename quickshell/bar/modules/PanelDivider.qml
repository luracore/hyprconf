import QtQuick
import QtQuick.Layouts

import qs.config

// Linha entre as seções dos painéis.
Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: Qt.alpha(Theme.colors.outline, 0.6)
}
