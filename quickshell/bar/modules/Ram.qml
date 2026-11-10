import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

BarButton {
    id: root

    property real ramUsage: 0

    clickable: false

    icon: "󰍛"
    label: Math.round(ramUsage) + "%"
    labelTemplate: "100%"

    accent: ramUsage < 50 ? "success" : ramUsage < 80 ? "warning" : "error"

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
