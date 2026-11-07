
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string themePath:
        Quickshell.env("HOME") + "/hyprconf/Themes/current"

    property var colors: ({})
    property string lastContent: ""

    function reload() {
        fileView.reload()
    }

    property FileView fileView: FileView {
        path: root.themePath

        onLoaded: {
            const content = text()

            if (content === root.lastContent)
                return

            try {
                root.colors = JSON.parse(content)
                root.lastContent = content
                console.log("Theme: paleta atualizada")
            } catch (error) {
                console.error("Theme: erro ao carregar paleta:", error)
            }
        }
    }

    property IpcHandler ipcHandler: IpcHandler {
        target: "theme"

        function reloadTheme(): void {
            root.reload()
        }
    }
}

