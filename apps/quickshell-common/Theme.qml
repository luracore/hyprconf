pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "Colors.js" as Colors

Singleton {
  id: root

  readonly property string themePath: Quickshell.shellPath("../../themes/current")

  // O FileView percebe edições no tema atual, mas não a troca do symlink
  // themes/current (o inotify fica no arquivo antigo): quem troca o tema
  // (themes/converters/main.js) chama o IPC "theme reloadTheme" de cada
  // Quickshell aberto.
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
  // Veja themes/Colors.js (symlink em apps/quickshell-common/).
  readonly property var colors: Colors.resolve(
    root.themeData, null, msg => console.warn("Theme:", msg)
  )

  // Camadas de interação: sobreposições translúcidas da cor do texto, para
  // funcionar tanto em temas escuros quanto claros.
  readonly property color hover: Qt.alpha(colors.text, 0.08)
  readonly property color selected: Qt.alpha(colors.text, 0.16)

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
