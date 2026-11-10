pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "ThemeColors.js" as ThemeColors

Singleton {
  id: root

  readonly property string themePath: Quickshell.shellPath("../../Themes/current")

  // Destino atual do symlink Themes/current. O FileView sozinho não percebe a
  // troca do symlink (o inotify fica no arquivo antigo), então comparamos o
  // destino periodicamente e recarregamos quando ele muda.
  property string linkTarget: ""

  // Tema usado para as cores obrigatórias que faltarem (ou se o arquivo falhar).
  readonly property var fallback: ({
    "neutrals": {
      "background": "#1F1F28",
      "text": "#DCD7BA"
    },
    "palette": {
      "red": "#E82424",
      "yellow": "#E6C384",
      "green": "#98BB6C",
      "cyan": "#7AA89F",
      "blue": "#7E9CD8",
      "magenta": "#957FB8"
    }
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

  // Tabela plana com neutros, paleta, papéis e on<Nome> calculados.
  // Veja config/ThemeColors.js.
  readonly property var colors: ThemeColors.resolve(
    root.themeData, root.fallback, msg => console.warn("Theme:", msg)
  )

  // Camadas de interação: sobreposições translúcidas da cor do texto, para
  // funcionar tanto em temas escuros quanto claros.
  readonly property color hover: Qt.alpha(colors.text, 0.08)
  readonly property color selected: Qt.alpha(colors.text, 0.16)

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
