import Quickshell.Io
import QtQuick

BarButton {
    id: root

    required property var powerMenu

    // ID do os-release -> ícone Nerd Font
    readonly property var icons: ({
        "arch": "",
        "cachyos": "",
        "endeavouros": "",
        "manjaro": "",
        "debian": "",
        "ubuntu": "",
        "fedora": "",
        "nixos": "",
        "opensuse-tumbleweed": "",
        "opensuse-leap": "",
        "gentoo": "",
        "void": ""
    })

    readonly property string distroId: {
        const match = /^ID="?([^"\n]+)"?$/m.exec(osRelease.text());
        return match ? match[1] : "";
    }

    icon: icons[distroId] ?? ""
    accent: "primary"
    active: powerMenu.open

    onClicked: powerMenu.toggle()

    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
    }
}
