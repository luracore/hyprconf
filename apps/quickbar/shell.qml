//@ pragma IconTheme Hyprconf
import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

// Uma barra só, no monitor escolhido no painel de monitores (clique no
// brilho), guardado por nome; sem escolha ou com ele desconectado, no
// primeiro da lista.
Scope {
    id: root

    property string preferredOutput: ""
    readonly property string statePath: Quickshell.shellPath("state/bar-monitor")

    function setPreferredOutput(name) {
        preferredOutput = name;
        Quickshell.execDetached(["sh", "-c", 'echo "$2" > "$1"', "sh", statePath, name]);
    }

    FileView {
        path: root.statePath
        printErrors: false
        onLoaded: root.preferredOutput = text().trim()
    }

    // Variants cria a janela de novo quando o monitor muda; só trocar o screen
    // de uma janela aberta não basta (a barra sumia quando o monitor dela era
    // desconectado)
    Variants {
        model: {
            const screen = Quickshell.screens.find(s => s.name === root.preferredOutput) ?? Quickshell.screens[0];
            return screen ? [screen] : [];
        }

        Bar {
            required property var modelData

            screen: modelData
            shell: root
        }
    }
}
