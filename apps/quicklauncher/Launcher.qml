import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "config/Typo.js" as Typo
import qs.config

// Substitui o hyprlauncher.
//   quickshell ipc --path ~/hyprconf/apps/quicklauncher call launcher toggle
Scope {
    id: root

    property bool open: false
    property string query: ""
    property int selected: 0

    readonly property int maxResults: 50
    readonly property int rowHeight: 52
    readonly property int visibleRows: 8

    function show() {
        query = "";
        selected = 0;
        pinTarget = null;
        input.text = "";
        open = true;
        input.forceActiveFocus();
    }

    function hide() {
        open = false;
        pinTarget = null;
    }

    function toggle() {
        if (open)
            hide();
        else
            show();
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }

    property var usage: ({})

    FileView {
        id: usageFile

        path: Quickshell.env("HOME") + "/.local/state/hyprconf/launcher-usage.json"
        blockLoading: true

        onLoaded: {
            try {
                root.usage = JSON.parse(text()) || {};
            } catch (error) {
                root.usage = {};
            }
        }
        onLoadFailed: root.usage = {}
    }

    function recordLaunch(entry) {
        const next = Object.assign({}, usage);
        next[entry.id] = (next[entry.id] || 0) + 1;
        usage = next;
        usageFile.setText(JSON.stringify(next));
    }

    function launch(entry) {
        if (!entry)
            return;

        recordLaunch(entry);
        hide();

        if (entry.runInTerminal)
            // apps de terminal abrem no terminal padrão (defaults.conf)
            Quickshell.execDetached([Quickshell.env("HOME") + "/hyprconf/apps/hyprrunner", "terminal", "-e"].concat(entry.command));
        else
            entry.execute();
    }

    property var pins: ({})           // "3" -> id do app
    readonly property var pinById: {  // id do app -> 3
        const map = {};
        for (const number in pins)
            map[pins[number]] = Number(number);
        return map;
    }

    function pinOf(entry) {
        return entry && pinById[entry.id] !== undefined ? pinById[entry.id] : -1;
    }

    FileView {
        id: pinsFile

        path: Quickshell.env("HOME") + "/.local/state/hyprconf/launcher-pins.json"
        blockLoading: true

        onLoaded: {
            try {
                root.pins = JSON.parse(text()) || {};
            } catch (error) {
                root.pins = {};
            }
        }
        onLoadFailed: root.pins = {}
    }

    // number < 0 remove o número do app
    function setPin(entry, number) {
        const next = {};
        for (const key in pins) {
            if (pins[key] !== entry.id && Number(key) !== number)
                next[key] = pins[key];
        }
        if (number >= 0)
            next[String(number)] = entry.id;

        pins = next;
        pinsFile.setText(JSON.stringify(next));

        pinTarget = null;
        selected = Math.max(0, results.indexOf(entry));
    }

    // app cujo seletor de número está aberto (botão direito)
    property var pinTarget: null

    function normalize(value) {
        return (value || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    // letras da busca em ordem dentro do texto; mais pontos quanto mais juntas
    function subsequence(text, q) {
        let pos = -1;
        let gaps = 0;
        for (const ch of q) {
            const next = text.indexOf(ch, pos + 1);
            if (next < 0)
                return 0;
            if (pos >= 0)
                gaps += next - pos - 1;
            pos = next;
        }
        // bônus quando começa pela primeira letra do nome ("nv" -> Neovim)
        const startBonus = text.startsWith(q[0]) ? 40 : 0;
        return Math.max(1, 100 - gaps * 4) + startBonus;
    }

    function score(entry, q) {
        const name = normalize(entry.name);
        let s = -1;

        if (name === q)
            s = 1000;
        else if (name.startsWith(q))
            s = 800;
        else if (name.split(/[\s\-_.]+/).some(word => word.startsWith(q)))
            s = 650;
        else if (name.includes(q))
            s = 500;
        else {
            const fuzzy = subsequence(name, q);
            if (fuzzy > 0)
                s = 200 + fuzzy;
        }

        if (s < 0) {
            const extra = normalize([entry.genericName, entry.comment, entry.id]
                .concat(entry.keywords || []).concat(entry.categories || []).join(" "));
            if (extra.includes(q))
                s = 150;
        }

        return s;
    }

    readonly property var results: {
        const q = normalize(query.trim());
        const list = [];

        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay)
                continue;

            const uses = usage[entry.id] || 0;

            if (q.length === 0) {
                const pin = pinById[entry.id];
                // com número: na frente de tudo, em ordem 0..9
                list.push({ entry: entry, score: pin !== undefined ? 1e9 - pin : uses });
                continue;
            }

            const s = score(entry, q);
            if (s >= 0)
                list.push({ entry: entry, score: s + Math.min(150, uses * 10) });
        }

        list.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return list.slice(0, maxResults).map(item => item.entry);
    }

    onResultsChanged: selected = 0

    function move(step) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + step));
    }

    PanelWindow {
        id: window

        visible: root.open || content.opacity > 0

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        color: "transparent"

        onVisibleChanged: {
            if (visible)
                input.forceActiveFocus();
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.colors.background
            opacity: root.open ? 0.45 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Rectangle {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18

            width: 600
            height: column.implicitHeight + 24

            radius: 16
            color: Theme.colors.background
            border.width: 1
            border.color: Qt.alpha(Theme.colors.outline, 0.8)

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // não deixa o clique no painel chegar ao fundo
            MouseArea {
                anchors.fill: parent
                onClicked: root.pinTarget = null
            }

            ColumnLayout {
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 12
                    color: Theme.colors.surface
                    border.width: input.activeFocus ? 1 : 0
                    border.color: Theme.colors.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "󰍉"
                            color: Theme.colors.primary
                            font.family: Typo.family
                            font.pixelSize: Typo.size.large + 2
                        }

                        TextInput {
                            id: input

                            Layout.fillWidth: true

                            color: Theme.colors.text
                            selectionColor: Qt.alpha(Theme.colors.primary, 0.4)
                            selectedTextColor: Theme.colors.text
                            font.family: Typo.family
                            font.pixelSize: Typo.size.large
                            clip: true

                            onTextChanged: root.query = text

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0
                                text: "Buscar aplicativos…"
                                color: Theme.colors.muted
                                font: input.font
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier;

                                // seletor de número aberto: 0-9 atribui, Delete remove, Esc fecha
                                if (root.pinTarget !== null) {
                                    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
                                        root.setPin(root.pinTarget, event.key - Qt.Key_0);
                                    else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
                                        root.setPin(root.pinTarget, -1);
                                    else if (event.key === Qt.Key_Escape)
                                        root.pinTarget = null;
                                    event.accepted = true;
                                    return;
                                }

                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                                        || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                    root.move(1);
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                                        || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                    root.move(-1);
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.move(root.visibleRows);
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.move(-root.visibleRows);
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launch(root.results[root.selected]);
                                } else if (event.key === Qt.Key_Escape) {
                                    root.hide();
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }
                    }
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    implicitHeight: Math.min(count, root.visibleRows) * root.rowHeight
                    visible: count > 0

                    model: root.results
                    currentIndex: root.selected
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    highlightMoveDuration: 120
                    highlightFollowsCurrentItem: true
                    highlight: Rectangle {
                        radius: 10
                        color: Qt.alpha(Theme.colors.primary, 0.14)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height * 0.5
                            radius: 2
                            color: Theme.colors.primary
                        }
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool current: index === root.selected

                        width: ListView.view.width
                        height: root.rowHeight

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Image {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                sourceSize.width: 64
                                sourceSize.height: 64
                                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                                asynchronous: true
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                    color: Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal
                                    font.weight: row.current ? Typo.weight.semibold : Typo.weight.medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: row.modelData.genericName || row.modelData.comment || ""
                                    elide: Text.ElideRight
                                    color: Theme.colors.muted
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.small
                                }
                            }

                            Text {
                                visible: row.modelData.runInTerminal
                                text: ""
                                color: Theme.colors.muted
                                font.family: Typo.family
                                font.pixelSize: Typo.size.normal
                            }

                            Rectangle {
                                readonly property int pin: root.pinOf(row.modelData)

                                visible: pin >= 0
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 7
                                color: Qt.alpha(Theme.colors.primary, row.current ? 0.3 : 0.16)
                                border.width: 1
                                border.color: Qt.alpha(Theme.colors.primary, 0.6)

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.pin
                                    color: Theme.colors.primary
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal - 1
                                    font.weight: Typo.weight.bold
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: {
                                if (root.pinTarget === null)
                                    root.selected = row.index;
                            }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.selected = row.index;
                                    root.pinTarget = row.modelData;
                                } else if (root.pinTarget !== null) {
                                    root.pinTarget = null;
                                } else {
                                    root.launch(row.modelData);
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "Nenhum aplicativo encontrado"
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.normal
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "↑↓ navegar  ·  Enter abrir  ·  botão direito: número  ·  Esc fechar"
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small - 1
                }
            }

            Rectangle {
                id: pinMenu

                readonly property int targetIndex: root.pinTarget ? root.results.indexOf(root.pinTarget) : -1
                readonly property int current: root.pinOf(root.pinTarget)
                readonly property real rowTop: column.y + list.y + targetIndex * root.rowHeight - list.contentY
                readonly property real below: rowTop + root.rowHeight - 4

                visible: root.pinTarget !== null && targetIndex >= 0
                z: 10

                width: pinColumn.implicitWidth + 24
                height: pinColumn.implicitHeight + 20
                x: content.width - width - 20
                y: below + height <= content.height ? below : rowTop - height + 4

                radius: 12
                color: Theme.colors.surface
                border.width: 1
                border.color: Theme.colors.primary

                // cliques dentro do seletor não fecham nada
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: pinColumn

                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "Número para " + (root.pinTarget ? root.pinTarget.name : "")
                        color: Theme.colors.text
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small
                        font.weight: Typo.weight.semibold
                    }

                    Row {
                        spacing: 6

                        Repeater {
                            model: 10

                            delegate: Rectangle {
                                id: numberButton

                                required property int index

                                readonly property bool isCurrent: index === pinMenu.current
                                // ocupado por outro app (atribuir aqui substitui)
                                readonly property bool taken: !isCurrent && root.pins[String(index)] !== undefined

                                width: 30
                                height: 30
                                radius: 8
                                color: isCurrent ? Theme.colors.primary
                                     : numberMouse.containsMouse ? Qt.alpha(Theme.colors.primary, 0.2)
                                     : Theme.colors.background
                                border.width: 1
                                border.color: isCurrent || numberMouse.containsMouse
                                    ? Theme.colors.primary : Qt.alpha(Theme.colors.outline, 0.8)

                                Text {
                                    anchors.centerIn: parent
                                    text: numberButton.index
                                    color: numberButton.isCurrent ? Theme.colors.onPrimary
                                         : numberButton.taken ? Theme.colors.muted
                                         : Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal
                                    font.weight: Typo.weight.semibold
                                }

                                Rectangle {
                                    visible: numberButton.taken
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.colors.warning
                                }

                                MouseArea {
                                    id: numberMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPin(root.pinTarget, numberButton.index)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "0–9 escolhe  ·  Esc cancela"
                            color: Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small - 1
                        }

                        Text {
                            visible: pinMenu.current >= 0
                            text: "Remover"
                            color: removeMouse.containsMouse ? Theme.colors.error : Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small
                            font.underline: removeMouse.containsMouse

                            MouseArea {
                                id: removeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setPin(root.pinTarget, -1)
                            }
                        }
                    }
                }
            }
        }
    }
}
