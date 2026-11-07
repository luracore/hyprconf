import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.themes

Text {
  id: root

  property real ramUsage: 0

  Layout.alignment: Qt.AlignVCenter

  text: "RAM " + Math.round(ramUsage) + "%"

  color: ramUsage < 50
    ? Theme.active.success
    : ramUsage < 80
      ? Theme.active.warning
      : Theme.active.error

  font {
    family: Typo.family
    pixelSize: Typo.normal
    weight: Typo.weight
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
