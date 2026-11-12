import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Painel do Sistema (aberto pelo módulo System): bateria (no notebook), CPU,
// RAM, temperatura e perfil de energia.
PanelSurface {
    id: root

    required property var sys          // o módulo System

    readonly property var battery: sys.battery

    // perfil de energia: o enum do PowerProfiles <-> chave dos chips
    readonly property var profileKeys: ({
        [PowerProfile.PowerSaver]: "saver",
        [PowerProfile.Balanced]: "balanced",
        [PowerProfile.Performance]: "performance"
    })
    readonly property var profileValues: ({
        "saver": PowerProfile.PowerSaver,
        "balanced": PowerProfile.Balanced,
        "performance": PowerProfile.Performance
    })

    // o power-profiles-daemon está rodando? (sem ele, não há perfis)
    property bool profilesAvailable: true

    CommandRunner { id: commands }

    onActiveChanged: {
        if (active)
            // pelo D-Bus direto: o powerprofilesctl precisa do python-gobject,
            // que nem sempre está instalado
            commands.run(["busctl", "--system", "get-property",
                          "org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles",
                          "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"],
                         code => root.profilesAvailable = code === 0);
    }

    function accentColorOf(accent) {
        return Theme.colors[accent] ?? Theme.colors.primary;
    }

    function gib(kib) {
        return (kib / 1048576).toFixed(1).replace(".", ",");
    }

    function batteryStatus() {
        if (!battery)
            return "";
        if (sys.full)
            return "Carregada";
        if (sys.charging) {
            const t = sys.duration(battery.timeToFull);
            return t ? "Carregando  ·  cheia em " + t : "Carregando";
        }
        if (sys.discharging) {
            const t = sys.duration(battery.timeToEmpty);
            return t ? "Na bateria  ·  resta " + t : "Na bateria";
        }
        return "Na tomada";
    }

    implicitWidth: 400

    PanelTitle { text: "SISTEMA" }

    // ---- bateria (só no notebook) ------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.sys.hasBattery
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                text: root.sys.batteryIcon()
                color: root.accentColorOf(root.sys.batteryAccent())
                font.family: Typo.family
                font.pixelSize: 40
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.sys.batteryPercent + "%"
                    color: Theme.colors.text
                    font.family: Typo.family
                    font.pixelSize: 26
                    font.weight: Typo.weight.bold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.batteryStatus()
                    wrapMode: Text.WordWrap
                    color: Theme.colors.muted
                    font.family: Typo.family
                    font.pixelSize: Typo.size.small
                }
            }
        }

        Meter {
            Layout.fillWidth: true
            fraction: root.sys.batteryPercent / 100
            barColor: root.accentColorOf(root.sys.batteryAccent())
        }

        Detail {
            visible: root.battery !== null && root.sys.discharging && root.battery.changeRate > 0
            label: "Consumo"
            value: root.battery ? root.battery.changeRate.toFixed(1).replace(".", ",") + " W" : ""
        }

        Detail {
            visible: root.battery !== null && root.battery.healthSupported
            label: "Saúde da bateria"
            value: root.battery ? Math.round(root.battery.healthPercentage <= 1
                ? root.battery.healthPercentage * 100 : root.battery.healthPercentage) + "%" : ""
        }

        PanelDivider {}
    }

    // ---- CPU, RAM e temperatura ----------------------------------------------

    MeterRow {
        Layout.fillWidth: true
        icon: "󰻠"
        label: "CPU"
        value: Math.round(root.sys.cpu) + "%"
        fraction: root.sys.cpu / 100
        barColor: root.accentColorOf(root.sys.cpuAccent())
    }

    MeterRow {
        Layout.fillWidth: true
        icon: "󰍛"
        label: "Memória"
        value: root.gib(root.sys.ramUsedKiB) + " de " + root.gib(root.sys.ramTotalKiB) + " GiB"
        fraction: root.sys.ram / 100
        barColor: root.accentColorOf(root.sys.ramAccent())
    }

    MeterRow {
        Layout.fillWidth: true
        visible: root.sys.temp >= 0
        icon: "󰔏"
        label: "Temperatura da CPU"
        value: Math.round(root.sys.temp) + " °C"
        // escala de 30 °C (frio) a 100 °C
        fraction: (root.sys.temp - 30) / 70
        barColor: root.accentColorOf(root.sys.tempAccent())
    }

    PanelDivider {}

    // ---- perfil de energia ------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        PanelChips {
            visible: root.profilesAvailable
            label: "Perfil de energia"
            options: [
                { value: "saver", label: "󰌪  Economia" },
                { value: "balanced", label: "󰗑  Equilibrado" }
            ].concat(PowerProfiles.hasPerformanceProfile
                ? [{ value: "performance", label: "󱐋  Desempenho" }] : [])
            value: root.profileKeys[PowerProfiles.profile] ?? ""
            onPicked: v => PowerProfiles.profile = root.profileValues[v]
        }

        Text {
            Layout.fillWidth: true
            visible: root.profilesAvailable && PowerProfiles.profile === PowerProfile.Performance
                && PowerProfiles.degradationReason !== PerformanceDegradationReason.None
            text: PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature
                ? "Desempenho limitado: temperatura alta"
                : "Desempenho limitado: notebook no colo"
            wrapMode: Text.WordWrap
            color: Theme.colors.warning
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Text {
            Layout.fillWidth: true
            visible: !root.profilesAvailable
            text: "Perfis de energia indisponíveis: o power-profiles-daemon não está rodando."
            wrapMode: Text.WordWrap
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }
    }

    // ---- componentes ------------------------------------------------------------

    component Meter: Rectangle {
        id: meter

        property real fraction: 0
        property color barColor: Theme.colors.primary

        implicitHeight: 6
        radius: 3
        color: Theme.colors.surface

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.fraction))
            height: parent.height
            radius: parent.radius
            color: meter.barColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // ícone + nome + valor, com a barra embaixo
    component MeterRow: ColumnLayout {
        id: row

        property string icon
        property string label
        property string value
        property real fraction: 0
        property color barColor: Theme.colors.primary

        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: row.icon
                color: row.barColor
                font.family: Typo.family
                font.pixelSize: Typo.size.normal + 2
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small + 1
            }

            Text {
                text: row.value
                color: Theme.colors.text
                font.family: Typo.family
                font.pixelSize: Typo.size.small + 1
                font.weight: Typo.weight.semibold
                font.features: { "tnum": 1 }
            }
        }

        Meter {
            Layout.fillWidth: true
            fraction: row.fraction
            barColor: row.barColor
        }
    }

    // linha "nome ........ valor"
    component Detail: RowLayout {
        id: detail

        property string label
        property string value

        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: detail.label
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Text {
            text: detail.value
            color: Theme.colors.text
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }
    }
}
