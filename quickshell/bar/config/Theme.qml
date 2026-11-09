pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string themePath: Quickshell.shellPath("../../Themes/current")

    // Destino atual do symlink Themes/current. O FileView sozinho não percebe a
    // troca do symlink (o inotify fica no arquivo antigo), então comparamos o
    // destino periodicamente e recarregamos quando ele muda.
    property string linkTarget: ""

    // Paleta neutra usada até o tema carregar (e caso ele falhe), para que
    // nenhum widget receba cores undefined durante a inicialização.
    readonly property var fallback: ({
        "background": "#101014",
        "surface": "#1A1A20",
        "foreground": "#E6E6E6",
        "border": "#33333D",
        "primary": "#4D91C9",
        "secondary": "#7A7A8C",
        "tertiary": "#A8B7C5",
        "error": "#E05252",
        "warning": "#E6A344",
        "success": "#83A982",
        "info": "#65A9D8",
        "on-accent": "#101014"
    })

    property FileView fileView: FileView {
        id: fileView

        path: root.themePath
        blockLoading: true
        watchChanges: true

        onFileChanged: root.reload()
        onLoadFailed: error => console.error(
            "Theme: não foi possível carregar", root.themePath, "- erro", error
        )
    }

    readonly property var themeData: {
        const content = fileView.text()

        if (content.length === 0)
            return ({})

        try {
            return JSON.parse(content)
        } catch (error) {
            console.error("Theme: JSON inválido em", root.themePath, "-", error)
            return ({})
        }
    }

    // Mescla com a paleta de fallback para que temas incompletos continuem válidos.
    property var colors: Object.assign({}, root.fallback, root.themeData)

    Process {
        id: linkProcess

        command: ["readlink", "-f", root.themePath]

        stdout: StdioCollector {
            onStreamFinished: {
                const target = text.trim()

                if (target.length === 0 || target === root.linkTarget)
                    return

                const previous = root.linkTarget
                root.linkTarget = target

                if (previous.length > 0)
                    root.reload()
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            if (!linkProcess.running)
                linkProcess.running = true
        }
    }

    function reload(): void {
        fileView.reload()
    }

    property IpcHandler ipcHandler: IpcHandler {
        target: "theme"

        function reloadTheme(): void {
            root.reload()
        }
    }
}
