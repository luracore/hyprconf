pragma Singleton

import QtQuick

QtObject {
    property string currentTheme: "TokyoNight"

    readonly property QtObject active:
        currentTheme === "Catppuccin"
            ? catppuccin
            : tokyoNight

    property QtObject tokyoNight: TokyoNight {}
    property QtObject catppuccin: Catppuccin {}
}
