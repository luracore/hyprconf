import Quickshell
import Quickshell.Hyprland
import QtQuick

import "../config/Sizes.js" as Sizes

// Janela dos painéis da barra. Todos abrem do mesmo jeito: a Sizes.bar.padding
// abaixo da barra, centralizados no módulo (ou, com align "start", alinhados
// ao começo dele) e nunca a menos de Sizes.bar.padding das bordas da tela, a
// mesma folga que a barra deixa nas pontas. Fecha ao clicar fora.
PopupWindow {
    id: popup

    required property Item module
    property string align: "center"     // "center" | "start"

    readonly property int gap: Sizes.bar.padding

    // posição do módulo na janela da barra; relida quando ele ou a fileira
    // dele andam (um workspace novo empurra os módulos, por exemplo)
    readonly property point origin: {
        module.x; module.y; module.width;
        module.parent?.x; module.parent?.y; module.parent?.width;
        return module.mapToItem(null, 0, 0);
    }
    readonly property real screenWidth: module.QsWindow.window?.width ?? 0

    readonly property real left: {
        const wanted = align === "start" ? origin.x : origin.x + (module.width - implicitWidth) / 2;
        return Math.max(gap, Math.min(screenWidth - implicitWidth - gap, wanted));
    }

    anchor.item: module
    anchor.rect.x: left - origin.x
    anchor.rect.y: Sizes.bar.height - origin.y + gap
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY

    color: "transparent"
    visible: false

    // o grab às vezes falha logo que a janela abre: tenta de novo por até 1 s
    property int grabAttempts: 0
    onVisibleChanged: grabAttempts = 0

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        active: popup.visible
        onCleared: popup.visible = false
    }

    Timer {
        interval: 50
        repeat: true
        running: popup.visible && !focusGrab.active && popup.grabAttempts < 20
        onTriggered: {
            popup.grabAttempts += 1;
            focusGrab.active = false;
            focusGrab.active = true;
        }
    }
}
