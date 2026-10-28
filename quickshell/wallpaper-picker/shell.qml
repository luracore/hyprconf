import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    implicitWidth: 500
    implicitHeight: 500

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    focusable: true
    color: "transparent"

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    ListModel {
        id: wallpapersModel
    }

    Process {
        id: currentWallpaperProcess

        command: ["bash", "-c", 'readlink -f "$HOME/hyprconf/Wallpapers/current"']

        stdout: StdioCollector {
            onStreamFinished: {
                carousel.currentWallpaperPath = text.trim();
                carousel.currentPathLoaded = true;
                carousel.selectCurrentWallpaperIfReady();
            }
        }

        Component.onCompleted: running = true
    }

    Process {
        id: wallpaperProcess

        command: ["bash", "/home/luracore/hyprconf/quickshell/wallpaper-picker/wallpapers.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();

                if (output.length > 0) {
                    const lines = output.split("\n");

                    for (const line of lines) {
                        const parts = line.split("\t");

                        if (parts.length !== 2)
                            continue;

                        wallpapersModel.append({
                            wallpaperPath: parts[0],
                            thumbnailPath: "file://" + parts[1]
                        });
                    }
                }

                carousel.wallpapersLoaded = true;
                carousel.selectCurrentWallpaperIfReady();
            }
        }

        Component.onCompleted: running = true
    }

    Process {
        id: applyWallpaperProcess

        property string selectedPath: ""

        command: ["bash", "-c", `
        wallpaper="$1"

        ln -sfn "$wallpaper" "$HOME/hyprconf/Wallpapers/current" &&
        awww img "$wallpaper" --resize crop --transition-type fade --transition-duration 1
    `, "wallpaper-picker", selectedPath]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                Qt.quit();
        }
    }

    Item {
        id: carousel

        anchors.centerIn: parent

        property string currentWallpaperPath: ""
        property bool currentPathLoaded: false
        property bool wallpapersLoaded: false
        property bool initialSelectionDone: false

        property int cellSize: 230
        property int cellSpacing: 10
        property int tileInset: 5
        property int imageInset: 3

        property int cellStep: cellSize + cellSpacing
        property int cellOffset: cellStep / 2

        property int columns: 3
        property int pendingIndex: 0

        width: (cellSize * 2) + (cellSpacing * 2)
        height: (cellSize * 2) + (cellSpacing * 2)

        clip: true

        function wrap(value, size) {
            return ((value % size) + size) % size;
        }

        function selectCurrentWallpaperIfReady() {
            if (!currentPathLoaded || !wallpapersLoaded || initialSelectionDone)
                return;

            initialSelectionDone = true;

            for (let i = 0; i < wallpapersModel.count; i++) {
                if (wallpapersModel.get(i).wallpaperPath === currentWallpaperPath) {
                    grid.currentIndex = i;
                    return;
                }
            }

            grid.currentIndex = 0;
        }

        function move(direction, vertical) {
            if (verticalAnimation.running || horizontalAnimation.running || wallpapersModel.count === 0)
                return;

            const step = vertical ? columns : 1;

            pendingIndex = wrap(grid.currentIndex + direction * step, wallpapersModel.count);

            if (vertical) {
                content.y = 0;
                verticalAnimation.from = 0;
                verticalAnimation.to = direction > 0 ? -cellStep : cellStep;
                verticalAnimation.start();
            } else {
                content.x = 0;
                horizontalAnimation.from = 0;
                horizontalAnimation.to = direction > 0 ? -cellStep : cellStep;
                horizontalAnimation.start();
            }
        }

        function applySelectedWallpaper() {
            if (wallpapersModel.count === 0 || applyWallpaperProcess.running)
                return;

            applyWallpaperProcess.selectedPath = wallpapersModel.get(grid.currentIndex).wallpaperPath;

            applyWallpaperProcess.running = true;
        }

        NumberAnimation {
            id: verticalAnimation

            target: content
            property: "y"
            duration: 180
            easing.type: Easing.OutCubic

            onFinished: {
                grid.currentIndex = carousel.pendingIndex;
                content.y = 0;
            }
        }

        NumberAnimation {
            id: horizontalAnimation

            target: content
            property: "x"
            duration: 180
            easing.type: Easing.OutCubic

            onFinished: {
                grid.currentIndex = carousel.pendingIndex;
                content.x = 0;
            }
        }

        Rectangle {
            anchors.fill: parent

            color: "transparent"
            border.width: 2
            border.color: "#f0c674"
            z: 1
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

                    property int rowOffset: Math.floor(index / 5) - 2
                    property int columnOffset: (index % 5) - 2

                    property int visualIndex: carousel.wrap(grid.currentIndex + rowOffset * carousel.columns + columnOffset, Math.max(1, wallpapersModel.count))

                    property bool selected: rowOffset === 0 && columnOffset === 0

                    x: (columnOffset + 1) * carousel.cellStep - carousel.cellOffset + carousel.tileInset

                    y: (rowOffset + 1) * carousel.cellStep - carousel.cellOffset + carousel.tileInset

                    width: carousel.cellSize
                    height: carousel.cellSize

                    radius: 8
                    color: "#303030"
                    visible: wallpapersModel.count > 0

                    Image {
                        anchors.fill: parent
                        anchors.margins: carousel.imageInset

                        source: wallpapersModel.count > 0 ? wallpapersModel.get(tile.visualIndex).thumbnailPath : ""

                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    border.width: tile.selected ? 3 : 2
                    border.color: tile.selected ? "#f0c674" : "#505050"
                }
            }
        }

        Item {
            id: grid

            property int currentIndex: 0

            focus: true
            activeFocusOnTab: true

            Component.onCompleted: forceActiveFocus()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    carousel.move(-1, false);
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    carousel.move(1, false);
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    carousel.move(-1, true);
                } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    carousel.move(1, true);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    carousel.applySelectedWallpaper();
                } else {
                    return;
                }

                event.accepted = true;
            }
        }
    }
}
