import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Servidor de notificações: popups no canto e a central (o sino da barra),
// com histórico e "não perturbe".
Scope {
    id: root

    // estado público (usado pelo botão na barra)
    property bool centerOpen: false
    property bool dnd: false
    readonly property int count: history.count

    readonly property int panelWidth: 380
    readonly property int popupTimeout: 5000

    function iconFor(appIcon) {
        if (!appIcon)
            return "";
        // caminho/URL direto ou nome de ícone do tema
        if (appIcon.startsWith("/") || appIcon.includes("://"))
            return appIcon;
        return Quickshell.iconPath(appIcon, true);
    }

    ListModel {
        id: history
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false

        onNotification: n => {
            history.insert(0, {
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                icon: root.iconFor(n.appIcon),
                urgency: n.urgency,
                time: Qt.formatDateTime(new Date(), "HH:mm")
            });

            // com "não perturbe" só críticas viram popup
            if (root.dnd && n.urgency !== NotificationUrgency.Critical)
                return;

            n.tracked = true;
        }
    }

    // qs ipc call notifications toggle|open|close|clear|toggleDnd
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.centerOpen = !root.centerOpen; }
        function open(): void { root.centerOpen = true; }
        function close(): void { root.centerOpen = false; }
        function clear(): void { history.clear(); }
        function toggleDnd(): void { root.dnd = !root.dnd; }
    }

    // ───────────────────────── popups ─────────────────────────
    PanelWindow {
        id: popups
        visible: !root.centerOpen && server.trackedNotifications.values.length > 0

        anchors { top: true; right: true }
        margins { top: Sizes.bar.height + Sizes.bar.padding; right: Sizes.bar.padding }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"

        color: "transparent"
        implicitWidth: root.panelWidth
        implicitHeight: Math.max(1, popupCol.implicitHeight)

        ColumnLayout {
            id: popupCol
            width: parent.width
            spacing: 10

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property var defaultAction:
                        modelData.actions.find(a => a.identifier === "default") ?? null

                    Layout.fillWidth: true
                    Layout.preferredHeight: cardLayout.implicitHeight + 20
                    radius: Sizes.radius.normal
                    color: Theme.colors.background
                    border.width: 2
                    border.color: critical ? Theme.colors.error : Theme.colors.primary

                    HoverHandler { id: hover }

                    // some sozinha depois do timeout (pausa com o mouse em cima)
                    Timer {
                        running: !card.critical && !hover.hovered
                        interval: root.popupTimeout
                        onTriggered: card.modelData.expire()
                    }

                    // clique: ação padrão se existir, senão fecha
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton && card.defaultAction)
                                card.defaultAction.invoke();
                            else
                                card.modelData.dismiss();
                        }
                    }

                    RowLayout {
                        id: cardLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Image {
                            readonly property string src:
                                card.modelData.image || root.iconFor(card.modelData.appIcon)
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(72, 72)
                            visible: src !== ""
                            source: src
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.summary
                                    color: Theme.colors.primary
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal
                                    font.weight: Typo.weight.bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: card.modelData.appName
                                    visible: text !== ""
                                    color: Theme.colors.muted
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.small
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.body
                                textFormat: Text.StyledText
                                color: Theme.colors.text
                                font.family: Typo.family
                                font.pixelSize: Typo.size.normal - 1
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                visible: actionsRep.count > 0

                                Repeater {
                                    id: actionsRep
                                    model: card.modelData.actions.filter(a => a.identifier !== "default")

                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: actionText.implicitWidth + 16
                                        implicitHeight: actionText.implicitHeight + 8
                                        radius: Sizes.radius.normal
                                        color: actionMouse.containsMouse ? Theme.colors.primary : Theme.colors.surface

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            color: actionMouse.containsMouse ? Theme.colors.onPrimary : Theme.colors.text
                                            font.family: Typo.family
                                            font.pixelSize: Typo.size.small
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: parent.modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ───────────────────── centro de notificações ─────────────────────
    PanelWindow {
        id: center
        visible: root.centerOpen

        anchors { top: true; right: true }
        margins { top: Sizes.bar.height + Sizes.bar.padding; right: Sizes.bar.padding }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notification-center"
        WlrLayershell.keyboardFocus: root.centerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        color: "transparent"
        implicitWidth: root.panelWidth
        implicitHeight: centerCol.implicitHeight + 24

        // fecha ao clicar fora
        HyprlandFocusGrab {
            windows: [center]
            active: root.centerOpen
            onCleared: root.centerOpen = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Sizes.radius.normal
            color: Theme.colors.background
            border.width: 2
            border.color: Theme.colors.primary

            focus: true
            Keys.onEscapePressed: root.centerOpen = false

            ColumnLayout {
                id: centerCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Notificações" + (history.count > 0 ? ` (${history.count})` : "")
                        color: Theme.colors.primary
                        font.family: Typo.family
                        font.pixelSize: Typo.size.normal + 2
                        font.weight: Typo.weight.bold
                    }

                    Text {
                        text: root.dnd ? "󰂛" : "󰂚"
                        color: root.dnd ? Theme.colors.warning : Theme.colors.text
                        font.family: Typo.family
                        font.pixelSize: Typo.size.large
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dnd = !root.dnd
                        }
                    }

                    Text {
                        text: "Limpar"
                        visible: history.count > 0
                        color: Theme.colors.error
                        font.family: Typo.family
                        font.pixelSize: Typo.size.normal - 1
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: history.clear()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    visible: history.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "󰂚\nNada por aqui"
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.normal
                    lineHeight: 1.4
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 520)
                    visible: history.count > 0
                    clip: true
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: history

                    delegate: Rectangle {
                        id: item
                        required property int index
                        required property string summary
                        required property string body
                        required property string appName
                        required property string icon
                        required property int urgency
                        required property string time

                        width: ListView.view.width
                        height: itemLayout.implicitHeight + 16
                        radius: Sizes.radius.normal
                        color: Theme.colors.surface
                        border.width: urgency === NotificationUrgency.Critical ? 1 : 0
                        border.color: Theme.colors.error

                        RowLayout {
                            id: itemLayout
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Image {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignTop
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(56, 56)
                                visible: item.icon !== ""
                                source: item.icon
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: item.summary
                                        color: Theme.colors.primary
                                        font.family: Typo.family
                                        font.pixelSize: Typo.size.normal - 1
                                        font.weight: Typo.weight.bold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: (item.appName ? item.appName + " · " : "") + item.time
                                        color: Theme.colors.muted
                                        font.family: Typo.family
                                        font.pixelSize: Typo.size.small
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: item.body
                                    textFormat: Text.StyledText
                                    color: Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.small
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignTop
                                text: "󰅖"
                                color: closeMouse.containsMouse ? Theme.colors.error : Theme.colors.muted
                                font.family: Typo.family
                                font.pixelSize: Typo.size.normal
                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: history.remove(item.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
