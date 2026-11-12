import QtQuick

import qs.config

// Controle deslizante dos painéis: value vai de 0 a 1; arrastar, clicar ou
// rolar emite moved(novo valor), e soltar o botão emite released.
Item {
    id: slider

    property real value: 0
    property color accent: Theme.colors.primary
    property real wheelStep: 0.05
    property bool wheelEnabled: true
    signal moved(real value)
    signal released

    implicitHeight: 20

    function emit(v) {
        slider.moved(Math.max(0, Math.min(1, v)));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.colors.surface

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, slider.value))
            height: parent.height
            radius: parent.radius
            color: slider.accent
        }
    }

    Rectangle {
        x: (slider.width - width) * Math.max(0, Math.min(1, slider.value))
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: Theme.colors.text
        border.width: 3
        border.color: slider.accent
        scale: sliderMouse.pressed || sliderMouse.containsMouse ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: sliderMouse

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function update(mouse) {
            slider.emit((mouse.x - 6) / slider.width);
        }

        onPressed: mouse => update(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                update(mouse);
        }
        onReleased: slider.released()
        onWheel: wheel => {
            if (slider.wheelEnabled)
                slider.emit(slider.value + (wheel.angleDelta.y > 0 ? slider.wheelStep : -slider.wheelStep));
            else
                wheel.accepted = false;
        }
    }
}
