import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Painel de monitores (aberto pelo módulo de brilho): um cartão por monitor
// com brilho e, em "Ajustes", resolução, taxa, escala e posição; embaixo, o
// modo noturno. Quem guarda o estado e aplica as mudanças é o Displays.qml.
PanelSurface {
    id: root

    required property var displays
    property var bar: null          // a janela da barra (Bar.qml)

    readonly property bool multi: displays.monitors.length > 1
    // cartões com "Ajustes" abertos (por nome do monitor): a lista de
    // monitores é relida a cada mudança e recria os cartões
    property var expanded: ({})

    implicitWidth: 400

    onActiveChanged: {
        if (active) {
            displays.refreshMonitors();
            for (const c of displays.controls)
                c.refresh();
        }
    }

    PanelTitle { text: "MONITORES" }

    Repeater {
        model: root.displays.monitors

        delegate: MonitorCard {}
    }

    Text {
        visible: root.displays.monitors.length === 0
        text: "Lendo os monitores…"
        color: Theme.colors.muted
        font.family: Typo.family
        font.pixelSize: Typo.size.small
    }

    // ---- confirmação ------------------------------------------------------------

    Rectangle {
        Layout.fillWidth: true
        visible: root.displays.pending
        implicitHeight: confirmLayout.implicitHeight + 20
        radius: Sizes.radius.normal
        color: Qt.alpha(Theme.colors.warning, 0.12)
        border.width: 1
        border.color: Qt.alpha(Theme.colors.warning, 0.6)

        ColumnLayout {
            id: confirmLayout

            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Manter a nova configuração? Volta sozinha em " + root.displays.countdown + " s."
                wrapMode: Text.WordWrap
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }

            RowLayout {
                spacing: 8

                PanelButton {
                    text: "Manter"
                    accent: Theme.colors.success
                    onClicked: root.displays.keep()
                }

                PanelButton {
                    text: "Voltar"
                    accent: Theme.colors.muted
                    onClicked: root.displays.revert()
                }
            }
        }
    }

    PanelDivider {}

    // ---- modo noturno -------------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰖔"
                color: root.displays.nightOn ? Theme.colors.warning : Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.large
            }

            Text {
                Layout.fillWidth: true
                text: "Modo noturno"
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small + 1
            }

            PanelSwitch {
                visible: root.displays.nightAvailable
                checked: root.displays.nightOn
                onToggled: root.displays.setNight(!root.displays.nightOn)
            }
        }

        // da esquerda (quente) para a direita (quase neutro)
        RowLayout {
            Layout.fillWidth: true
            visible: root.displays.nightAvailable && root.displays.nightOn
            spacing: 12

            PanelSlider {
                Layout.fillWidth: true
                accent: Theme.colors.warning
                value: (root.displays.nightTemp - root.displays.nightMin) / (root.displays.nightMax - root.displays.nightMin)
                onMoved: v => root.displays.setNightTemp(root.displays.nightMin + v * (root.displays.nightMax - root.displays.nightMin))
            }

            Text {
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignRight
                text: root.displays.nightTemp + " K"
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small
                font.features: { "tnum": 1 }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.displays.nightAvailable
            text: "Precisa do hyprsunset (sudo pacman -S hyprsunset)."
            wrapMode: Text.WordWrap
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }
    }

    // ---- cartão de um monitor ---------------------------------------------------------

    component MonitorCard: ColumnLayout {
        id: card

        required property var modelData
        readonly property var mon: modelData
        readonly property var control: root.displays.controlFor(mon.name)
        readonly property var modes: root.displays.modesOf(mon)
        readonly property string res: mon.width + "x" + mon.height
        readonly property var resolutions: modes.map(m => m.res).filter((r, i, all) => all.indexOf(r) === i)
        readonly property var rates: modes.filter(m => m.res === res)
        // o modo da lista mais perto da taxa atual (a lista arredonda)
        readonly property string currentMode: rates.reduce((best, m) =>
            best === null || Math.abs(m.rate - mon.refreshRate) < Math.abs(best.rate - mon.refreshRate) ? m : best, null)?.mode ?? ""
        readonly property var saved: root.displays.saved[mon.name] ?? {}
        readonly property real scale: Number(mon.scale.toFixed(2))
        // escalas que o Hyprland aceita neste monitor: a resolução dividida
        // pela escala tem que dar pixels inteiros (senão ele troca por outra);
        // e a tela não fica menor que 960 pixels de largura
        readonly property var scales: [0.5, 0.75, 0.8, 1, 1.25, 1.5, 1.6, 2, 2.5, 3]
            .filter(s => {
                const w = mon.width / s, h = mon.height / s;
                return Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01 && w >= 960;
            })
            .concat([scale]).filter((s, i, all) => all.indexOf(s) === i).sort((a, b) => a - b)
        readonly property string position: mon.mirrorOf && mon.mirrorOf !== "none" ? "mirror" : (saved.position ?? "auto")

        readonly property bool expanded: root.expanded[mon.name] === true
        property bool pickingResolution: false

        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: root.displays.isInternal(card.mon.name) ? "󰌢" : "󰍹"
                color: Theme.colors.warning
                font.family: Typo.family
                font.pixelSize: 26
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.displays.isInternal(card.mon.name) ? "Tela do notebook" : (card.mon.model || card.mon.description || card.mon.name)
                    elide: Text.ElideRight
                    color: Theme.colors.text
                    font.family: Typo.family
                    font.pixelSize: Typo.size.normal
                    font.weight: Typo.weight.semibold
                }

                Text {
                    Layout.fillWidth: true
                    text: card.mon.name + "  ·  " + card.res + "  ·  " + root.displays.rateLabel(card.mon.refreshRate)
                        + "  ·  " + Math.round(card.mon.scale * 100) + "%"
                    elide: Text.ElideRight
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small - 1
                }
            }

            PanelIconButton {
                icon: card.expanded ? "󰅃" : "󰒓"
                onClicked: {
                    root.expanded = Object.assign({}, root.expanded, { [card.mon.name]: !card.expanded });
                    card.pickingResolution = false;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.control !== null
            spacing: 12

            Text {
                text: "󰃠"
                color: Theme.colors.warning
                font.family: Typo.family
                font.pixelSize: Typo.size.large
            }

            PanelSlider {
                Layout.fillWidth: true
                enabled: card.control !== null && card.control.ready
                opacity: enabled ? 1 : 0.5
                accent: Theme.colors.warning
                value: card.control && card.control.ready ? card.control.brightness / 100 : 0
                onMoved: v => card.control.set(v * 100)
            }

            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: card.control && card.control.ready ? card.control.brightness + "%" : "--"
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.normal - 1
                font.weight: Typo.weight.semibold
            }
        }

        // em qual monitor a barra fica (só com mais de um)
        RowLayout {
            Layout.fillWidth: true
            visible: root.multi && root.bar !== null
            spacing: 10

            readonly property bool here: root.bar !== null && root.bar.screen !== null && root.bar.screen.name === card.mon.name

            Text {
                visible: parent.here
                text: "󱔓  A barra está aqui"
                color: Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }

            PanelButton {
                visible: !parent.here
                text: "Mostrar a barra aqui"
                onClicked: {
                    // o painel é preso à barra: fecha antes de ela mudar de monitor
                    root.closeRequested();
                    root.bar.setPreferredOutput(card.mon.name);
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: card.control === null
            text: "O brilho deste monitor não dá para mudar por aqui (sem DDC/CI)."
            wrapMode: Text.WordWrap
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: card.expanded
            enabled: !root.displays.pending
            opacity: enabled ? 1 : 0.5
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Resolução"
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small - 1
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Sizes.radius.normal
                    color: resMouse.containsMouse ? Theme.hover : Theme.colors.surface

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.res.replace("x", " × ")
                        color: Theme.colors.text
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.pickingResolution ? "󰅃" : "󰅀"
                        color: Theme.colors.muted
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small
                    }

                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pickingResolution = !card.pickingResolution
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    visible: card.pickingResolution
                    implicitHeight: Math.min(contentHeight, 180)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: card.resolutions

                    delegate: Rectangle {
                        id: resItem

                        required property string modelData
                        readonly property bool current: modelData === card.res

                        width: ListView.view.width
                        height: 28
                        radius: Sizes.radius.normal
                        color: current ? Theme.selected : itemMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: resItem.modelData.replace("x", " × ")
                            color: resItem.current ? Theme.colors.text : Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small
                            font.weight: resItem.current ? Typo.weight.semibold : Typo.weight.regular
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.pickingResolution = false;
                                // a maior taxa dessa resolução
                                const best = card.modes.filter(m => m.res === resItem.modelData)
                                    .reduce((a, b) => b.rate > a.rate ? b : a);
                                root.displays.change(card.mon, { mode: best.mode });
                            }
                        }
                    }
                }
            }

            PanelChips {
                Layout.fillWidth: true
                visible: card.rates.length > 1
                label: "Taxa de atualização"
                options: card.rates.map(m => ({ value: m.mode, label: root.displays.rateLabel(m.rate) }))
                value: card.currentMode
                onPicked: v => root.displays.change(card.mon, { mode: v })
            }

            // escala: o slider para só nas escalas válidas e aplica ao soltar
            ColumnLayout {
                id: scaleRow

                Layout.fillWidth: true
                spacing: 4

                readonly property int current: Math.max(0, card.scales.indexOf(card.scale))
                property int dragging: -1
                readonly property int shown: dragging >= 0 ? dragging : current

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Escala"
                        color: Theme.colors.muted
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small - 1
                    }

                    Text {
                        text: Math.round(card.scales[scaleRow.shown] * 100) + "%"
                        color: scaleRow.dragging >= 0 && scaleRow.dragging !== scaleRow.current
                            ? Theme.colors.primary : Theme.colors.text
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small
                        font.weight: Typo.weight.semibold
                        font.features: { "tnum": 1 }
                    }
                }

                PanelSlider {
                    Layout.fillWidth: true
                    visible: card.scales.length > 1
                    wheelEnabled: false
                    value: scaleRow.shown / Math.max(1, card.scales.length - 1)
                    onMoved: v => scaleRow.dragging = Math.round(v * (card.scales.length - 1))
                    onReleased: {
                        const picked = scaleRow.dragging;
                        scaleRow.dragging = -1;
                        if (picked >= 0 && picked !== scaleRow.current)
                            root.displays.change(card.mon, { scale: card.scales[picked] });
                    }
                }

                // as paradas do slider, cada número embaixo do centro da bolinha
                // (que anda de 8 a largura - 8)
                Item {
                    id: ticks

                    Layout.fillWidth: true
                    visible: card.scales.length > 1
                    implicitHeight: 12

                    Repeater {
                        model: card.scales

                        delegate: Text {
                            required property real modelData
                            required property int index

                            x: Math.max(0, Math.min(ticks.width - width,
                                8 + (ticks.width - 16) * index / Math.max(1, card.scales.length - 1) - width / 2))
                            text: Math.round(modelData * 100)
                            color: index === scaleRow.shown ? Theme.colors.text : Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small - 2
                        }
                    }
                }
            }

            PanelChips {
                Layout.fillWidth: true
                visible: root.multi
                label: "Posição em relação aos outros"
                options: [
                    { value: "auto", label: "Automática" },
                    { value: "auto-left", label: "Esquerda" },
                    { value: "auto-right", label: "Direita" },
                    { value: "auto-up", label: "Acima" },
                    { value: "auto-down", label: "Abaixo" },
                    { value: "mirror", label: "Espelhar" }
                ]
                value: card.position
                onPicked: v => {
                    if (v === "mirror") {
                        // espelha o primeiro outro monitor (de preferência a tela do notebook)
                        const others = root.displays.monitors.filter(m => m.name !== card.mon.name);
                        const target = others.find(m => root.displays.isInternal(m.name)) ?? others[0];
                        root.displays.change(card.mon, { position: "auto", mirror: target.name });
                    } else {
                        root.displays.change(card.mon, { position: v, mirror: "" });
                    }
                }
            }
        }

        PanelDivider { visible: root.multi; opacity: 0.6 }
    }
}
