import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

BarButton {
    id: root

    property real cpuUsage: 0
    property real lastCpuIdle: -1
    property real lastCpuTotal: -1

    clickable: false

    icon: "󰻠"
    label: Math.round(cpuUsage) + "%"
    labelTemplate: "100%"

    accent: cpuUsage < 50 ? "primary" : cpuUsage < 80 ? "warning" : "error"

    Process {
        id: cpuProcess

        command: ["cat", "/proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: root.updateCpu(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!cpuProcess.running)
                cpuProcess.running = true
        }
    }

    function updateCpu(output) {
        const fields = output.split("\n")[0].trim().split(/\s+/)

        if (fields.length < 8)
            return

        let total = 0
        for (let i = 1; i <= 8; i++)
            total += Number(fields[i])

        // idle + iowait
        const idle = Number(fields[4]) + Number(fields[5])

        if (lastCpuTotal >= 0) {
            const deltaTotal = total - lastCpuTotal
            const deltaIdle = idle - lastCpuIdle

            if (deltaTotal > 0)
                cpuUsage = 100 * (1 - deltaIdle / deltaTotal)
        }

        lastCpuTotal = total
        lastCpuIdle = idle
    }
}
