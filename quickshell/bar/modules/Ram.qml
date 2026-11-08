import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

Text {
    id: root

    property real ramUsage: 0

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: ramMetrics.width

    horizontalAlignment: Text.AlignRight

    text: "RAM " + Math.round(ramUsage) + "%"

    color: ramUsage < 50
        ? Theme.colors.success
        : ramUsage < 80
            ? Theme.colors.warning
            : Theme.colors.error

    font {
        family: Typo.family.default
        pixelSize: Typo.size.normal
        weight: Typo.weight.medium
    }

    TextMetrics {
        id: ramMetrics

        font: root.font
        text: "RAM 100%"
    }

    Process {
        id: ramProcess

        command: ["cat", "/proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                const total = Number(
                    text.match(/MemTotal:\s+(\d+)/)?.[1]
                )

                const available = Number(
                    text.match(/MemAvailable:\s+(\d+)/)?.[1]
                )

                if (total > 0 && available >= 0) {
                    root.ramUsage = 100 * (1 - available / total)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!ramProcess.running)
                ramProcess.running = true
        }
    }
}
