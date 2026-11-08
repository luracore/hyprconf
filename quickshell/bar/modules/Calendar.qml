import Quickshell
import QtQml
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

Rectangle {
    id: root

    // Exposto para o Clock pausar a animação quando o popup está fechado.
    property bool active: true

    signal closeRequested()

    property date today: clock.date
    property int monthOffset: 0
    property var selectedDay: null

    property date displayedMonth: addMonths(startOfMonth(today), monthOffset)

    readonly property int cellWidth: 40
    readonly property int cellHeight: 34
    readonly property int cellSpacing: 3
    readonly property color mutedColor: Qt.darker(Theme.colors.foreground, 1.6)

    implicitWidth: 340
    implicitHeight: layout.implicitHeight + 24

    color: Theme.colors.background
    radius: Sizes.radius.normal + 2
    border.width: 1
    border.color: Theme.colors.border

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.active
        onActivated: root.closeRequested()
    }

    function startOfMonth(value) {
        return new Date(value.getFullYear(), value.getMonth(), 1)
    }

    function addMonths(value, amount) {
        return new Date(value.getFullYear(), value.getMonth() + amount, 1)
    }

    function sameDay(a, b) {
        return a !== null
            && b !== null
            && a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function dayAt(index) {
        const first = startOfMonth(displayedMonth)
        const start = new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay())
        return new Date(start.getFullYear(), start.getMonth(), start.getDate() + index)
    }

    function capitalize(value) {
        return value.length > 0 ? value[0].toUpperCase() + value.slice(1) : value
    }

    function weekdayName(index) {
        return capitalize(Qt.locale().dayName(index, Locale.ShortFormat).replace(".", ""))
    }

    function reset() {
        monthOffset = 0
        selectedDay = null
    }

    function previousMonth() {
        monthOffset -= 1
        selectedDay = null
    }

    function nextMonth() {
        monthOffset += 1
        selectedDay = null
    }

    function goToToday() {
        monthOffset = 0
        selectedDay = null
    }

    function selectDay(value) {
        selectedDay = sameDay(value, today) ? null : value
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Relógio grande
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: layout.width
            spacing: 0

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 1

                Text {
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: Theme.colors.foreground

                    font {
                        family: Typo.family.default
                        pixelSize: 42
                        weight: Typo.weight.medium
                    }
                }

                Text {
                    id: colon

                    text: ":"
                    color: Theme.colors.foreground

                    font {
                        family: Typo.family.default
                        pixelSize: 42
                        weight: Typo.weight.medium
                    }

                    SequentialAnimation on opacity {
                        running: root.active
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1
                            to: 0.25
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 0.25
                            to: 1
                            duration: 500
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Theme.colors.foreground

                    font {
                        family: Typo.family.default
                        pixelSize: 42
                        weight: Typo.weight.medium
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter

                text: clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                color: root.mutedColor

                font {
                    family: Typo.family.default
                    pixelSize: Typo.size.small + 2
                    weight: Typo.weight.medium
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.border
        }

        // Cabeçalho do calendário
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true

                text: root.capitalize(Qt.formatDate(root.displayedMonth, "MMMM yyyy"))
                color: Theme.colors.foreground

                font {
                    family: Typo.family.default
                    pixelSize: Typo.size.normal + 1
                    weight: Typo.weight.bold
                }
            }

            Rectangle {
                implicitWidth: todayLabel.implicitWidth + 16
                implicitHeight: 26

                radius: Sizes.radius.normal
                color: todayMouse.containsMouse
                    ? Qt.lighter(Theme.colors.surface, 1.15)
                    : "transparent"

                Text {
                    id: todayLabel

                    anchors.centerIn: parent
                    text: "Hoje"
                    color: root.mutedColor

                    font {
                        family: Typo.family.default
                        pixelSize: Typo.size.small + 2
                        weight: Typo.weight.medium
                    }
                }

                MouseArea {
                    id: todayMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToToday()
                }
            }

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26

                radius: Sizes.radius.normal
                color: prevMouse.containsMouse
                    ? Qt.lighter(Theme.colors.surface, 1.15)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: prevMouse.containsMouse ? Theme.colors.foreground : root.mutedColor

                    font {
                        family: Typo.family.default
                        pixelSize: 20
                        weight: Typo.weight.medium
                    }
                }

                MouseArea {
                    id: prevMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previousMonth()
                }
            }

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26

                radius: Sizes.radius.normal
                color: nextMouse.containsMouse
                    ? Qt.lighter(Theme.colors.surface, 1.15)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: nextMouse.containsMouse ? Theme.colors.foreground : root.mutedColor

                    font {
                        family: Typo.family.default
                        pixelSize: 20
                        weight: Typo.weight.medium
                    }
                }

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextMonth()
                }
            }
        }

        // Grade 6x7
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: gridColumn.implicitHeight + 16

            color: Theme.colors.surface
            radius: Sizes.radius.normal

            Column {
                id: gridColumn

                anchors.centerIn: parent
                spacing: root.cellSpacing

                Row {
                    spacing: root.cellSpacing

                    Repeater {
                        model: 7

                        Text {
                            required property int index

                            width: root.cellWidth
                            height: 20

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: root.weekdayName(index)
                            color: index === 0 || index === 6
                                ? Theme.colors.secondary
                                : root.mutedColor
                            opacity: index === 0 || index === 6 ? 0.85 : 1

                            font {
                                family: Typo.family.default
                                pixelSize: Typo.size.small
                                weight: 600
                            }
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: root.cellSpacing

                    Repeater {
                        model: 42

                        Rectangle {
                            id: cell

                            required property int index

                            readonly property date day: root.dayAt(index)
                            readonly property bool inMonth: day.getMonth() === root.displayedMonth.getMonth()
                            readonly property bool isToday: root.sameDay(day, root.today)
                            readonly property bool isSelected: root.sameDay(day, root.selectedDay)
                            readonly property bool isWeekend: day.getDay() === 0 || day.getDay() === 6

                            width: root.cellWidth
                            height: root.cellHeight
                            radius: Sizes.radius.normal

                            color: isToday
                                ? Theme.colors.primary
                                : isSelected
                                    ? Qt.lighter(Theme.colors.surface, 1.5)
                                    : cellMouse.containsMouse
                                        ? Qt.lighter(Theme.colors.surface, 1.25)
                                        : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: cell.day.getDate()

                                color: cell.isToday
                                    ? Theme.colors.background
                                    : !cell.inMonth
                                        ? Theme.colors.border
                                        : cell.isSelected
                                            ? Theme.colors.primary
                                            : cell.isWeekend
                                                ? Theme.colors.secondary
                                                : Theme.colors.foreground

                                opacity: cell.inMonth ? 1 : 0.55

                                font {
                                    family: Typo.family.default
                                    pixelSize: Typo.size.normal
                                    weight: cell.isToday
                                        ? Typo.weight.bold
                                        : Typo.weight.medium
                                }
                            }

                            MouseArea {
                                id: cellMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectDay(cell.day)
                            }
                        }
                    }
                }
            }
        }
    }
}
