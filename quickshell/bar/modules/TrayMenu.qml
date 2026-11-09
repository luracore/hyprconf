import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

PopupWindow {
    id: root

    property Item anchorItem: null
    property var rootMenu: null
    property var currentMenu: null
    property var menuStack: []

    function open(menu, item) {
        if (!menu)
            return

        anchorItem = item
        rootMenu = menu
        currentMenu = menu
        menuStack = []

        if (visible)
            root.anchor.updateAnchor()
        else
            visible = true
    }

    function push(entry) {
        menuStack = menuStack.concat([{
            label: entry.text,
            menu: root.currentMenu
        }])

        currentMenu = entry
    }

    function pop() {
        if (menuStack.length === 0)
            return

        currentMenu = menuStack[menuStack.length - 1].menu
        menuStack = menuStack.slice(0, -1)
    }

    function close() {
        visible = false
    }

    onVisibleChanged: {
        if (!visible) {
            currentMenu = null
            rootMenu = null
            menuStack = []
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem ? Sizes.bar.height - anchorItem.mapToItem(null, 0, 0).y + 4 : 0
    anchor.rect.width: anchorItem ? anchorItem.width : 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    color: "transparent"
    visible: false

    implicitWidth: frame.implicitWidth
    implicitHeight: Math.min(frame.implicitHeight, 560)

    QsMenuOpener {
        id: rootOpener

        menu: root.rootMenu
    }

    QsMenuOpener {
        id: opener

        menu: root.currentMenu
    }

    HyprlandFocusGrab {
        id: grab

        windows: [root]
        active: root.visible

        onCleared: root.close()
    }

    Rectangle {
        id: frame

        anchors.fill: parent

        implicitWidth: menuColumn.implicitWidth + 16
        implicitHeight: menuColumn.implicitHeight + 16

        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.border
        radius: Sizes.radius.normal

        Flickable {
            id: scroller

            anchors.fill: parent
            anchors.margins: 8

            contentWidth: width
            contentHeight: menuColumn.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: menuColumn

                width: scroller.width
                height: implicitHeight
                spacing: 2

                Rectangle {
                    visible: root.menuStack.length > 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    radius: Sizes.radius.normal - 2
                    color: backMouse.containsMouse ? Theme.colors.background : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "←"
                            color: Theme.colors.secondary

                            font {
                                family: Typo.family.default
                                pixelSize: Typo.size.normal
                                weight: Typo.weight.medium
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            text: root.menuStack.length > 0
                                ? root.menuStack[root.menuStack.length - 1].label
                                : ""

                            color: Theme.colors.foreground
                            elide: Text.ElideRight

                            font {
                                family: Typo.family.default
                                pixelSize: Typo.size.normal
                                weight: Typo.weight.medium
                            }
                        }
                    }

                    MouseArea {
                        id: backMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.pop()
                    }
                }

                Repeater {
                    model: opener.children

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property bool isSeparator: entry.modelData.isSeparator
                        readonly property bool isSubmenu: entry.modelData.hasChildren
                        readonly property bool isEnabled: entry.modelData.enabled
                        readonly property bool isCheckable: entry.modelData.buttonType !== QsMenuButtonType.None
                        readonly property bool isChecked: entry.modelData.checkState === Qt.Checked
                        readonly property bool hasIcon: entry.modelData.icon !== ""

                        Layout.fillWidth: true
                        Layout.preferredHeight: entry.isSeparator ? 9 : 32
                        Layout.preferredWidth: entry.isSeparator ? 0 : entryRow.implicitWidth + 20

                        radius: Sizes.radius.normal - 2
                        color: !entry.isSeparator && entryMouse.containsMouse && entry.isEnabled
                            ? Theme.colors.background
                            : "transparent"

                        Rectangle {
                            visible: entry.isSeparator

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6

                            height: 1
                            color: Theme.colors.border
                        }

                        RowLayout {
                            id: entryRow

                            visible: !entry.isSeparator

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Item {
                                visible: entry.isCheckable

                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14

                                Text {
                                    anchors.centerIn: parent

                                    text: entry.isChecked
                                        ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓")
                                        : ""

                                    color: Theme.colors.primary

                                    font {
                                        family: Typo.family.default
                                        pixelSize: Typo.size.small
                                        weight: Typo.weight.bold
                                    }
                                }
                            }

                            Image {
                                visible: entry.hasIcon

                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16

                                source: entry.modelData.icon
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true

                                text: entry.modelData.text
                                color: entry.isEnabled
                                    ? Theme.colors.foreground
                                    : Theme.colors.border

                                elide: Text.ElideRight

                                font {
                                    family: Typo.family.default
                                    pixelSize: Typo.size.normal
                                    weight: Typo.weight.medium
                                }
                            }

                            Text {
                                visible: entry.isSubmenu

                                text: "›"
                                color: Theme.colors.secondary

                                font {
                                    family: Typo.family.default
                                    pixelSize: Typo.size.large
                                    weight: Typo.weight.medium
                                }
                            }
                        }

                        MouseArea {
                            id: entryMouse

                            anchors.fill: parent
                            enabled: !entry.isSeparator && entry.isEnabled
                            hoverEnabled: true
                            cursorShape: entry.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                if (entry.isSubmenu) {
                                    root.push(entry.modelData)
                                } else {
                                    entry.modelData.triggered()
                                    root.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible

        onActivated: root.close()
    }
}
