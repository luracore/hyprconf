import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// Prioridade (do mais urgente):
//   bateria ≤ 15% descarregando > temperatura ≥ 90 °C > CPU ≥ 85% > RAM ≥ 90%
//   > temperatura ≥ 80 °C > padrão (bateria no notebook, CPU no PC)
BarButton {
    id: root

    property real cpu: 0
    property real ram: 0
    property real ramUsedKiB: 0
    property real ramTotalKiB: 0
    property real temp: -1             // °C, -1 = sem sensor
    property string tempPath: ""       // arquivo do sensor, achado no início

    property real lastIdle: -1
    property real lastTotal: -1

    // /proc/stat: "cpu user nice system idle iowait irq softirq steal"
    function parseStat(text) {
        const f = text.slice(0, text.indexOf("\n")).trim().split(/\s+/);
        if (f[0] !== "cpu" || f.length < 9)
            return;
        let total = 0;
        for (let i = 1; i <= 8; i++)
            total += Number(f[i]);
        const idle = Number(f[4]) + Number(f[5]);
        if (lastTotal >= 0 && total > lastTotal)
            cpu = 100 * (1 - (idle - lastIdle) / (total - lastTotal));
        lastTotal = total;
        lastIdle = idle;
    }

    function parseMem(text) {
        const memTotal = Number((text.match(/MemTotal:\s+(\d+)/) || [])[1]);
        const memAvailable = Number((text.match(/MemAvailable:\s+(\d+)/) || [])[1]);
        if (memTotal > 0) {
            ramTotalKiB = memTotal;
            ramUsedKiB = memTotal - memAvailable;
            ram = 100 * ramUsedKiB / memTotal;
        }
    }

    // o sensor dá a temperatura em miligraus
    function parseTemp(text) {
        const milli = Number(text.trim());
        if (!isNaN(milli) && milli > 0)
            temp = milli / 1000;
    }

    CommandRunner { id: commands }

    // acha o sensor da CPU: Intel (coretemp), AMD (k10temp/zenpower), ARM
    // (cpu_thermal) e, por último, o da placa (acpitz)
    readonly property string findSensor: [
        'for want in coretemp k10temp zenpower cpu_thermal acpitz; do',
        '  for h in /sys/class/hwmon/hwmon*; do',
        '    [ "$(cat "$h/name" 2>/dev/null)" = "$want" ] || continue',
        '    for l in "$h"/temp*_label; do',
        '      case "$(cat "$l" 2>/dev/null)" in',
        '        "Package id 0"|Tctl|Tdie) echo "${l%_label}_input"; exit 0 ;;',
        '      esac',
        '    done',
        '    [ -e "$h/temp1_input" ] && { echo "$h/temp1_input"; exit 0; }',
        '  done',
        'done',
        'exit 1'
    ].join("\n")

    Component.onCompleted: {
        commands.run(["sh", "-c", findSensor], (code, out) => {
            if (code === 0)
                tempPath = out.trim();
        });
    }

    // lidos direto (sem abrir um processo a cada leitura)
    FileView { id: statFile; path: "/proc/stat"; onLoaded: root.parseStat(text()) }
    FileView { id: memFile; path: "/proc/meminfo"; onLoaded: root.parseMem(text()) }
    FileView { id: tempFile; path: root.tempPath; onLoaded: root.parseTemp(text()) }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (root.tempPath !== "")
                tempFile.reload();
        }
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: UPower.devices.values.some(d => d.isLaptopBattery)
    // 0-100 (o UPower do Quickshell dá 0-1)
    readonly property int batteryPercent: {
        const p = battery ? battery.percentage : 0;
        return Math.round(p <= 1 ? p * 100 : p);
    }
    readonly property bool charging: battery !== null
        && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: battery !== null && battery.state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: hasBattery && !charging && !full && UPower.onBattery

    function batteryIcon() {
        if (charging)
            return "󰂄";
        if (full)
            return "󰂅";
        const icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return icons[Math.max(0, Math.min(10, Math.round(batteryPercent / 10)))];
    }

    // "1h 20min", "35min"
    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round(seconds % 3600 / 60);
        return h > 0 ? h + "h " + String(m).padStart(2, "0") + "min" : m + "min";
    }

    // alertas com folga para desligar (histerese)
    property bool batteryLow: false
    property bool tempCritical: false
    property bool cpuHigh: false
    property bool ramHigh: false
    property bool tempHigh: false

    onBatteryPercentChanged: batteryLow = discharging && (batteryPercent <= 15 || (batteryLow && batteryPercent <= 18))
    onDischargingChanged: batteryLow = discharging && batteryPercent <= 15
    onCpuChanged: cpuHigh = cpu >= 85 || (cpuHigh && cpu >= 75)
    onRamChanged: ramHigh = ram >= 90 || (ramHigh && ram >= 85)
    onTempChanged: {
        tempCritical = temp >= 90 || (tempCritical && temp >= 85);
        tempHigh = temp >= 80 || (tempHigh && temp >= 75);
    }

    readonly property string shown: batteryLow ? "battery"
        : tempCritical ? "temp"
        : cpuHigh ? "cpu"
        : ramHigh ? "ram"
        : tempHigh ? "temp"
        : hasBattery ? "battery"
        : "cpu"

    // cor de cada métrica (também usada no painel)
    function cpuAccent() { return cpu >= 95 ? "error" : cpu >= 85 ? "warning" : "primary"; }
    function ramAccent() { return ram >= 95 ? "error" : ram >= 90 ? "warning" : "success"; }
    function tempAccent() { return temp >= 90 ? "error" : temp >= 80 ? "warning" : "info"; }
    function batteryAccent() {
        if (charging || full)
            return "success";
        return batteryPercent <= 15 ? "error" : batteryPercent <= 30 ? "warning" : "success";
    }

    icon: shown === "battery" ? batteryIcon()
        : shown === "temp" ? "󰔏"
        : shown === "ram" ? "󰍛"
        : "󰻠"
    label: shown === "battery" ? batteryPercent + "%"
        : shown === "temp" ? Math.round(temp) + "°C"
        : shown === "ram" ? Math.round(ram) + "%"
        : Math.round(cpu) + "%"
    labelTemplate: "100%"
    accent: shown === "battery" ? batteryAccent()
        : shown === "temp" ? tempAccent()
        : shown === "ram" ? ramAccent()
        : cpuAccent()
    active: popup.visible

    onClicked: m => {
        if (m.button === Qt.LeftButton)
            root.togglePanel();
    }

    function togglePanel() {
        popup.visible = !popup.visible;
    }

    BarPopup {
        id: popup

        module: root
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight

        SystemPanel {
            id: panel

            anchors.fill: parent
            sys: root
            active: popup.visible
            onCloseRequested: popup.visible = false
        }
    }

    // qs ipc call system togglePanel
    IpcHandler {
        target: "system"
        function togglePanel(): void { root.togglePanel(); }
    }

}
