import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Título de seção dos painéis da barra (ex.: "WI-FI").
Text {
    color: Theme.colors.muted
    font.family: Typo.family
    font.pixelSize: Typo.size.small
    font.weight: Typo.weight.bold
    font.letterSpacing: 2
}
