import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

BarButton {
    id: root

    property int grabAttempts: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    icon: "󰃰"
    label: Qt.formatDateTime(clock.date, "ddd dd  HH:mm")
    accent: "primary"
    active: popup.visible

    onClicked: root.toggleCalendar()

    function toggleCalendar() {
        grabAttempts = 0

        if (popup.visible) {
            popup.visible = false
        } else {
            calendar.reset()
            popup.visible = true
        }
    }

    PopupWindow {
        id: popup

        anchor.item: root
        anchor.rect.width: root.width
        anchor.rect.height: root.height
        anchor.rect.x: (root.width - calendar.implicitWidth) / 2
        anchor.rect.y: Sizes.bar.height - root.y + 6
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

        implicitWidth: calendar.implicitWidth
        implicitHeight: calendar.implicitHeight
        color: "transparent"

        visible: false

        Calendar {
            id: calendar

            anchors.fill: parent
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    HyprlandFocusGrab {
        id: focusGrab

        windows: [popup]
        active: popup.visible

        onCleared: popup.visible = false
    }

    Timer {
        interval: 50
        repeat: true
        running: popup.visible && !focusGrab.active && root.grabAttempts < 20
        onTriggered: {
            root.grabAttempts += 1
            focusGrab.active = false
            focusGrab.active = true
        }
    }

    IpcHandler {
        target: "bar"

        function toggleCalendar(): void {
            root.toggleCalendar()
        }

        function nextMonth(): void {
            calendar.nextMonth()
        }

        function previousMonth(): void {
            calendar.previousMonth()
        }

        function selectOffset(days: int): void {
            const value = new Date(calendar.today)
            value.setDate(value.getDate() + days)
            calendar.selectDay(value)
        }
    }
}
