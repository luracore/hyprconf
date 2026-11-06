pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property string currentTheme: "TokyoNight"

    property Component tokyoNightComponent: Qt.createComponent("TokyoNight.qml")
    property Component catppuccinComponent: Qt.createComponent("Catppuccin.qml")

    readonly property QtObject tokyoNight: tokyoNightComponent.createObject(null)
    readonly property QtObject catppuccin: catppuccinComponent.createObject(null)

    readonly property QtObject active:
        currentTheme === "Catppuccin"
            ? catppuccin
            : tokyoNight
}
