import Quickshell
import Quickshell.Io
import QtQuick

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

BarButton {
    id: root

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
        if (popup.visible) {
            popup.visible = false
        } else {
            calendar.reset()
            popup.visible = true
        }
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: calendar.implicitWidth
        implicitHeight: calendar.implicitHeight

        Calendar {
            id: calendar

            anchors.fill: parent
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call bar toggleCalendar|nextMonth|previousMonth|selectOffset <dias>
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
