import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Botão de módulo no estilo "block-prefix" do Wayle:
// [ ícone ][ valor ]  -> bloco quadrado colorido + valor na mesma cor sobre surface
Rectangle {
    id: root

    property string icon: ""
    property int iconSize: Typo.size.large + 2
    property string label: ""
    // texto mais largo esperado; fixa a largura pra não "pular" (ex. "100%")
    property string labelTemplate: ""

    // nome da cor no tema: primary, secondary, tertiary, success, warning, error, info
    property string accent: "primary"
    readonly property color accentColor: Theme.colors[accent] ?? Theme.colors.primary
    readonly property color onAccentColor:
        Theme.colors["on" + accent.charAt(0).toUpperCase() + accent.slice(1)] ?? Theme.colors.background
    property color labelColor: accentColor

    property bool showIcon: icon !== ""
    property bool showLabel: label !== ""
    property bool bordered: false
    property bool active: false      // destaque (ex. popup aberto)
    property bool clickable: true

    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    // +1 por "clique" da roda pra cima, -1 pra baixo (touchpad acumula)
    signal scrolled(int steps)

    property real _wheelAcc: 0

    Layout.alignment: Qt.AlignVCenter
    implicitHeight: Sizes.module.height
    implicitWidth: (showIcon ? iconBlock.width : 0) + (showLabel ? labelBox.width : 0)

    radius: Sizes.module.radius
    color: Theme.colors.surface
    border.width: bordered || active ? 1 : 0
    border.color: accentColor

    // bloco do ícone
    Rectangle {
        id: iconBlock
        visible: root.showIcon
        width: root.height
        height: root.height
        radius: root.radius
        color: root.accentColor

        // deixa o lado direito reto, "colando" no valor
        Rectangle {
            visible: root.showLabel
            anchors.right: parent.right
            width: parent.radius
            height: parent.height
            color: parent.color
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.onAccentColor
            font.family: Typo.family
            font.pixelSize: root.iconSize
        }
    }

    // valor
    Item {
        id: labelBox
        visible: root.showLabel
        anchors.left: root.showIcon ? iconBlock.right : parent.left
        width: Math.max(labelText.implicitWidth, metrics.width) + 2 * Sizes.module.labelPadding
        height: root.height

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.label
            color: root.labelColor
            font.family: Typo.family
            font.pixelSize: Typo.size.normal - 1
            font.weight: Typo.weight.semibold
        }
    }

    TextMetrics {
        id: metrics
        font: labelText.font
        text: root.labelTemplate
    }

    // hover
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.colors.text
        opacity: root.clickable && root.hovered ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: m => root.clicked(m)
        onWheel: w => {
            root._wheelAcc += w.angleDelta.y;
            const steps = Math.trunc(root._wheelAcc / 120);
            if (steps !== 0) {
                root._wheelAcc -= steps * 120;
                root.scrolled(steps);
            }
        }
    }
}
