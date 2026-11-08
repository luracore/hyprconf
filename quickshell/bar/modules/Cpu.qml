import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config/Typo.js" as Typo
import qs.config

Text {
    id: root

    property real cpuUsage: 0
    property real lastCpuIdle: -1
    property real lastCpuTotal: -1

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: cpuMetrics.width

    horizontalAlignment: Text.AlignRight

    text: "CPU " + Math.round(cpuUsage) + "%"

    color: cpuUsage < 50
        ? Theme.colors.success
        : cpuUsage < 80
            ? Theme.colors.warning
            : Theme.colors.error

    font {
        family: Typo.family.default
        pixelSize: Typo.size.normal
        weight: Typo.weight.medium
    }

    TextMetrics {
        id: cpuMetrics

        font: root.font
        text: "CPU 100%"
    }

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
