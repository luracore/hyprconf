import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    implicitWidth: 900
    implicitHeight: 600

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    focusable: true
    color: "transparent"

    ListModel {
        id: wallpapersModel
    }

    Process {
        id: wallpaperProcess

        command: [
            "bash",
            "/home/luracore/hyprconf/quickshell/wallpaper-picker/wallpapers.sh"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                for (const line of lines) {
                    const parts = line.split("\t")

                    if (parts.length !== 2)
                        continue

                    wallpapersModel.append({
                        wallpaperPath: parts[0],
                        thumbnailPath: "file://" + parts[1]
                    })
                }
            }
        }

        Component.onCompleted: running = true
    }

    Item {
        id: carousel

        anchors.centerIn: parent

        width: 600
        height: 400

        clip: true

        property int columns: 3
        property int pendingIndex: 0

        function wrap(value, size) {
            return ((value % size) + size) % size
        }

        function move(direction, vertical) {
            if (moveAnimation.running ||
                horizontalAnimation.running ||
                wallpapersModel.count === 0)
                return

            const step = vertical ? columns : 1

            pendingIndex = wrap(
                grid.currentIndex + direction * step,
                wallpapersModel.count
            )

            if (vertical) {
                content.y = 0
                moveAnimation.from = 0
                moveAnimation.to = direction > 0 ? -200 : 200
                moveAnimation.start()
            } else {
                content.x = 0
                horizontalAnimation.from = 0
                horizontalAnimation.to = direction > 0 ? -200 : 200
                horizontalAnimation.start()
            }
        }

        NumberAnimation {
            id: moveAnimation

            target: content
            property: "y"
            duration: 180
            easing.type: Easing.OutCubic

            onFinished: {
                grid.currentIndex = carousel.pendingIndex
                content.y = 0
            }
        }

        NumberAnimation {
            id: horizontalAnimation

            target: content
            property: "x"
            duration: 180
            easing.type: Easing.OutCubic

            onFinished: {
                grid.currentIndex = carousel.pendingIndex
                content.x = 0
            }
        }

        Item {
            id: content

            width: carousel.width
            height: carousel.height

            Repeater {
                model: 25

                delegate: Rectangle {
                    id: tile

                    required property int index

                    // Posição relativa à seleção central.
                    property int rowOffset: Math.floor(index / 5) - 2
                    property int columnOffset: (index % 5) - 2

                    // Cada tile representa um wallpaper da lista circular.
                    property int visualIndex: carousel.wrap(
                        grid.currentIndex
                            + rowOffset * carousel.columns
                            + columnOffset,
                        Math.max(1, wallpapersModel.count)
                    )

                    property bool selected: rowOffset === 0
                                            && columnOffset === 0

                    x: (columnOffset + 1) * 200 + 5
                    y: (rowOffset + 1) * 200 - 100 + 5

                    width: 190
                    height: 190

                    radius: 8
                    color: "#303030"

                    visible: wallpapersModel.count > 0

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3

                        source: wallpapersModel.count > 0
                            ? wallpapersModel.get(tile.visualIndex).thumbnailPath
                            : ""

                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    border.width: tile.selected ? 3 : 2
                    border.color: tile.selected
                        ? "#f0c674"
                        : "#505050"
                }
            }
        }

        // Índice lógico da seleção.
        Item {
            id: grid

            property int currentIndex: 0

            focus: true
            activeFocusOnTab: true

            Component.onCompleted: forceActiveFocus()

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_H ||
                    event.key === Qt.Key_Left) {
                    carousel.move(-1, false)
                } else if (event.key === Qt.Key_L ||
                           event.key === Qt.Key_Right) {
                    carousel.move(1, false)
                } else if (event.key === Qt.Key_K ||
                           event.key === Qt.Key_Up) {
                    carousel.move(-1, true)
                } else if (event.key === Qt.Key_J ||
                           event.key === Qt.Key_Down) {
                    carousel.move(1, true)
                } else {
                    return
                }

                event.accepted = true
            }
        }
    }
}

