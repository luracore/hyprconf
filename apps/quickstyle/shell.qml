import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

import "Colors.js" as Colors
import "Typo.js" as Typo

// Seletor de wallpaper + tema, em cruz:
//   carrossel horizontal de wallpapers  ×  roleta vertical de temas.
// O carrossel usado por último vem para a frente; o outro recua.
//
//   h/l ou ←/→  wallpaper     j/k ou ↑/↓  tema
//   Enter  aplica os dois     w  só wallpaper     t  só tema     Esc  sai
PanelWindow {
    id: root

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickstyle"
    WlrLayershell.layer: WlrLayer.Overlay

    focusable: true
    color: "transparent"

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    // ---- estado -------------------------------------------------------------

    property var wallpapers: []          // [{ path, thumb, name }]
    property var themes: []              // [{ path, name, colors }]

    property string currentWallpaper: ""   // aplicado de fato (symlink)
    property string currentTheme: ""       // aplicado de fato (symlink)

    property bool wallpapersLoaded: false
    property bool themesLoaded: false
    property bool currentLoaded: false
    property bool shown: false

    readonly property int wallCount: wallpapers.length
    readonly property int themeCount: themes.length

    // Posições dos carrosséis: *Target é inteiro e sem limites (os carrosséis
    // dão voltas); *Pos segue o alvo com animação. Teclas repetidas só mudam
    // o alvo, e a animação em curso é redirecionada sem saltos.
    property int wallTarget: 0
    property real wallPos: wallTarget
    readonly property int wallIndex: wrap(wallTarget, Math.max(1, wallCount))
    readonly property var selectedWallpaper: wallCount > 0 ? wallpapers[wallIndex] : null

    property int themeTarget: 0
    property real themePos: themeTarget
    readonly property int themeIndex: wrap(themeTarget, Math.max(1, themeCount))
    readonly property var selectedTheme: themeCount > 0 ? themes[themeIndex] : null

    // Qual carrossel está na frente. A troca é imediata na lógica; "depth"
    // (0 = wallpapers na frente, 1 = temas na frente) anima a parte visual.
    property string activeCarousel: "wallpapers"     // "wallpapers" | "themes"
    property real depth: activeCarousel === "themes" ? 1 : 0

    readonly property var motionCurve: [0.22, 1, 0.36, 1, 1, 1]

    Behavior on wallPos {
        enabled: root.shown
        NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
    }

    Behavior on themePos {
        enabled: root.shown
        NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
    }

    Behavior on depth {
        NumberAnimation { duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: root.motionCurve }
    }

    function wrap(value, size) {
        return ((value % size) + size) % size;
    }

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function baseName(path) {
        return path.split("/").pop().replace(/\.[^.]+$/, "");
    }

    // Os carrosséis usam 7 "vagas" fixas. A vaga j mostra a posição
    // s ≡ j (mod 7) mais próxima de pos, de modo que cada vaga só troca de
    // conteúdo quando está fora da área visível.
    readonly property int slotCount: 7

    function slotFor(index, pos) {
        return index + slotCount * Math.round((pos - index) / slotCount);
    }

    // Distância a partir da qual um item some (com 0.5 de fade). Limitada pela metade do total,
    // para o mesmo item nunca aparecer duas vezes ao mesmo tempo.
    function fadeEnd(count, maxDistance) {
        return Math.min(maxDistance, count / 2);
    }

    // ---- cores --------------------------------------------------------------

    function resolveTheme(data) {
        return Colors.resolve(data, null, msg => console.warn("quickstyle:", msg));
    }

    readonly property var preview: selectedTheme ? selectedTheme.colors : resolveTheme(Colors.FALLBACK)

    // ---- carregamento -------------------------------------------------------

    function selectCurrentIfReady() {
        if (!wallpapersLoaded || !themesLoaded || !currentLoaded || shown)
            return;

        for (let i = 0; i < wallpapers.length; i++) {
            if (wallpapers[i].path === currentWallpaper) {
                wallTarget = i;
                break;
            }
        }

        for (let i = 0; i < themes.length; i++) {
            if (themes[i].path === currentTheme) {
                themeTarget = i;
                break;
            }
        }

        Qt.callLater(() => root.shown = true);
    }

    Process {
        command: ["bash", "-c",
            'readlink -f "$HOME/hyprconf/Wallpapers/current"; readlink -f "$HOME/hyprconf/Themes/current"']

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.currentWallpaper = (lines[0] || "").trim();
                root.currentTheme = (lines[1] || "").trim();
                root.currentLoaded = true;
                root.selectCurrentIfReady();
            }
        }

        Component.onCompleted: running = true
    }

    Process {
        command: ["bash", Quickshell.shellPath("wallpapers.sh")]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];

                for (const line of text.split("\n")) {
                    const parts = line.split("\t");
                    if (parts.length !== 2)
                        continue;

                    list.push({
                        path: parts[0],
                        thumb: "file://" + parts[1],
                        name: root.baseName(parts[0])
                    });
                }

                root.wallpapers = list;
                root.wallpapersLoaded = true;
                root.selectCurrentIfReady();
            }
        }

        Component.onCompleted: running = true
    }

    Process {
        command: ["bash", Quickshell.shellPath("themes.sh")]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];

                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;

                    const path = line.slice(0, tab);
                    let data;

                    try {
                        data = JSON.parse(line.slice(tab + 1));
                    } catch (error) {
                        console.warn("quickstyle: JSON inválido em", path);
                        continue;
                    }

                    list.push({
                        path: path,
                        name: root.baseName(path),
                        colors: root.resolveTheme(data)
                    });
                }

                root.themes = list;
                root.themesLoaded = true;
                root.selectCurrentIfReady();
            }
        }

        Component.onCompleted: running = true
    }

    // ---- aplicar ------------------------------------------------------------

    Process {
        id: applyProcess

        property string wallpaper: ""
        property string theme: ""

        command: ["bash", "-c", `
            wallpaper="$1"
            theme="$2"

            if [[ -n "$theme" ]]; then
                ln -sfn "$theme" "$HOME/hyprconf/Themes/current" || exit 1

                # foot, neovim, GTK e Qt (a barra recarrega sozinha)
                node "$HOME/hyprconf/Themes/converters/main.js" ||
                    echo "quickstyle: Themes/converters/main.js falhou" >&2
            fi

            if [[ -n "$wallpaper" ]]; then
                ln -sfn "$wallpaper" "$HOME/hyprconf/Wallpapers/current" &&
                awww img "$wallpaper" --resize crop --transition-type fade --transition-duration 1
            fi
        `, "quickstyle", wallpaper, theme]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                Qt.quit();
            else
                console.error("quickstyle: falha ao aplicar (código", exitCode + ")");
        }
    }

    function apply(withWallpaper, withTheme) {
        if (applyProcess.running)
            return;

        const wallpaper = withWallpaper && selectedWallpaper && selectedWallpaper.path !== currentWallpaper
            ? selectedWallpaper.path : "";
        const theme = withTheme && selectedTheme && selectedTheme.path !== currentTheme
            ? selectedTheme.path : "";

        if (wallpaper === "" && theme === "") {
            Qt.quit();
            return;
        }

        applyProcess.wallpaper = wallpaper;
        applyProcess.theme = theme;
        applyProcess.running = true;
    }

    function moveWallpaper(step) {
        activeCarousel = "wallpapers";
        if (wallCount > 0)
            wallTarget += step;
    }

    function moveTheme(step) {
        activeCarousel = "themes";
        if (themeCount > 0)
            themeTarget += step;
    }

    // ---- interface ----------------------------------------------------------

    Item {
        id: stage

        anchors.fill: parent

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        focus: true
        Component.onCompleted: forceActiveFocus()

        // Centro comum dos dois carrosséis.
        readonly property real cx: width / 2
        readonly property real cy: height / 2

        // Medidas proporcionais à tela.
        readonly property real cardWidth: Math.min(760, width * 0.40, height * 0.62 * 16 / 9)
        readonly property real cardHeight: cardWidth * 9 / 16
        readonly property real themeWidth: Math.min(440, Math.max(320, cardWidth * 0.58))
        readonly property real themeHeight: 112

        // Cores do tema em destaque, com transição suave ao trocar de tema.
        Item {
            id: ui
            visible: false

            property color background: root.preview.background
            property color surface: root.preview.surface
            property color outline: root.preview.outline
            property color muted: root.preview.muted
            property color text: root.preview.text
            property color primary: root.preview.primary

            Behavior on background { ColorAnimation { duration: 320 } }
            Behavior on surface { ColorAnimation { duration: 320 } }
            Behavior on outline { ColorAnimation { duration: 320 } }
            Behavior on muted { ColorAnimation { duration: 320 } }
            Behavior on text { ColorAnimation { duration: 320 } }
            Behavior on primary { ColorAnimation { duration: 320 } }
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_H:
            case Qt.Key_Left:
                root.moveWallpaper(-1);
                break;
            case Qt.Key_L:
            case Qt.Key_Right:
                root.moveWallpaper(1);
                break;
            case Qt.Key_K:
            case Qt.Key_Up:
                root.moveTheme(-1);
                break;
            case Qt.Key_J:
            case Qt.Key_Down:
                root.moveTheme(1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.apply(true, true);
                break;
            case Qt.Key_W:
                root.apply(true, false);
                break;
            case Qt.Key_T:
                root.apply(false, true);
                break;
            case Qt.Key_Escape:
            case Qt.Key_Q:
                Qt.quit();
                break;
            default:
                return;
            }

            event.accepted = true;
        }

        // ---- fundo: prévia do wallpaper com blur + tinta do tema -----------

        Rectangle {
            anchors.fill: parent
            color: ui.background
        }

        Item {
            id: backdrop

            anchors.fill: parent
            visible: false

            Repeater {
                model: root.wallpapers

                delegate: Loader {
                    id: backdropImage

                    required property var modelData
                    required property int index

                    readonly property real distance: {
                        const n = Math.max(1, root.wallCount);
                        let d = root.wrap(index - root.wallPos, n);
                        if (d >= n / 2)
                            d -= n;
                        return Math.abs(d);
                    }

                    anchors.fill: parent
                    active: distance < 1.5
                    opacity: root.clamp01(1 - distance)

                    sourceComponent: Image {
                        source: backdropImage.modelData.thumb
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: backdrop
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: -0.15
        }

        Rectangle {
            anchors.fill: parent
            color: ui.background
            opacity: 0.55
        }

        // vinheta, para destacar o centro e os atalhos
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(ui.background, 0.45) }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha(ui.background, 0.85) }
            }
        }

        // Scroll: move o carrossel que está na frente (Shift alterna).
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            property real accumulator: 0

            onWheel: wheel => {
                let delta = wheel.angleDelta.y;
                let wallpapersAxis = root.activeCarousel === "wallpapers";

                if (wheel.angleDelta.x !== 0 && Math.abs(wheel.angleDelta.x) > Math.abs(delta)) {
                    delta = wheel.angleDelta.x;
                    wallpapersAxis = true;
                } else if (wheel.modifiers & Qt.ShiftModifier) {
                    wallpapersAxis = !wallpapersAxis;
                }

                accumulator += delta;

                while (Math.abs(accumulator) >= 120) {
                    const step = accumulator > 0 ? -1 : 1;
                    if (wallpapersAxis)
                        root.moveWallpaper(step);
                    else
                        root.moveTheme(step);
                    accumulator += step * 120;
                }
            }
        }

        // ---- roleta de temas -----------------------------------------------
        //
        // A roleta existe em duas cópias idênticas: uma atrás dos wallpapers e
        // outra na frente. A troca de plano é um crossfade entre as duas
        // (atrás = 1 - depth, frente = depth), então a sobreposição muda de
        // forma contínua, sem salto de z-index.

        Component {
            id: themeWheel

            Item {
                id: wheel

                anchors.fill: parent

                // a roleta cresce quando vem para a frente
                scale: 0.88 + 0.2 * root.depth
                transformOrigin: Item.Center

                readonly property real step: stage.cardHeight / 2 + stage.themeHeight / 2 + 44
                readonly property real limit: root.fadeEnd(root.themeCount, 2.4)

                Repeater {
                    model: root.themeCount > 0 ? root.slotCount : 0

                    delegate: Item {
                        id: themeCard

                        required property int index

                        readonly property int slot: root.slotFor(index, root.themePos)
                        readonly property real d: slot - root.themePos
                        readonly property real ad: Math.abs(d)
                        readonly property real near: 1 - Math.min(ad, 1)        // 1 no centro, 0 a partir do vizinho
                        readonly property var theme: root.themes[root.wrap(slot, root.themeCount)]
                        readonly property var c: theme ? theme.colors : root.preview
                        readonly property bool active: theme && theme.path === root.currentTheme

                        // quanto este card está "em foco" (centro e roleta na frente)
                        readonly property real focusAmount: near * (0.35 + 0.65 * root.depth)

                        width: stage.themeWidth
                        height: stage.themeHeight

                        x: stage.cx - width / 2
                        y: stage.cy - height / 2
                           + Math.sign(d) * (wheel.step * Math.min(ad, 1) + wheel.step * 0.82 * Math.max(ad - 1, 0))

                        scale: 1 - 0.15 * Math.min(ad, 1) - 0.12 * Math.max(ad - 1, 0)
                        opacity: root.clamp01((wheel.limit - ad) / 0.5) * (1 - 0.3 * Math.min(ad, 1))
                        visible: opacity > 0.001
                        z: 100 - ad * 10

                        // perspectiva sutil: inclina para longe do centro
                        transform: Rotation {
                            origin.x: themeCard.width / 2
                            origin.y: themeCard.height / 2
                            axis { x: 1; y: 0; z: 0 }
                            angle: -root.clamp(themeCard.d, -1.6, 1.6) * 16
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 20
                            blur: 0.35 * Math.min(themeCard.ad, 1) + 0.2 * (1 - root.depth)
                            brightness: -0.18 * (1 - themeCard.focusAmount)
                            shadowEnabled: true
                            shadowColor: Qt.tint("#000000", Qt.alpha(themeCard.c.primary, 0.75 * themeCard.focusAmount))
                            shadowOpacity: 0.45 + 0.2 * themeCard.focusAmount
                            shadowBlur: 1.0
                            shadowVerticalOffset: 10 * (1 - themeCard.focusAmount)
                        }

                        // vidro
                        Rectangle {
                            anchors.fill: parent
                            radius: 20
                            color: Qt.alpha(themeCard.c.background, 0.78)
                            border.width: 1 + 1.5 * themeCard.near
                            border.color: Qt.tint(Qt.alpha(themeCard.c.outline, 0.7),
                                                  Qt.alpha(themeCard.c.primary, themeCard.near))

                            // reflexo superior
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: parent.radius - 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.alpha(themeCard.c.text, 0.08) }
                                    GradientStop { position: 0.5; color: "transparent" }
                                }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 14

                            Item {
                                width: parent.width
                                height: themeName.implicitHeight

                                Text {
                                    id: themeName

                                    anchors.left: parent.left
                                    anchors.right: activeTag.left
                                    anchors.rightMargin: 8

                                    text: themeCard.theme ? themeCard.theme.name : ""
                                    elide: Text.ElideRight
                                    color: themeCard.c.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.large
                                    font.weight: Typo.weight.semibold
                                }

                                Rectangle {
                                    id: activeTag

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter

                                    visible: themeCard.active
                                    width: visible ? activeText.implicitWidth + 16 : 0
                                    height: activeText.implicitHeight + 6
                                    radius: height / 2
                                    color: Qt.alpha(themeCard.c.primary, 0.2)
                                    border.width: 1
                                    border.color: Qt.alpha(themeCard.c.primary, 0.5)

                                    Text {
                                        id: activeText

                                        anchors.centerIn: parent
                                        text: "● atual"
                                        color: themeCard.c.primary
                                        font.family: Typo.family
                                        font.pixelSize: Typo.size.small
                                        font.weight: Typo.weight.medium
                                    }
                                }
                            }

                            Row {
                                spacing: 8

                                Repeater {
                                    model: ["red", "orange", "yellow", "green", "cyan", "blue", "magenta"]

                                    delegate: Rectangle {
                                        required property string modelData

                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: themeCard.c[modelData]
                                        border.width: 1
                                        border.color: Qt.alpha(themeCard.c.text, 0.18)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.activeCarousel = "themes";
                                root.themeTarget = themeCard.slot;
                            }
                            onDoubleClicked: {
                                root.themeTarget = themeCard.slot;
                                root.apply(false, true);
                            }
                        }
                    }
                }
            }
        }

        // roleta atrás dos wallpapers
        Loader {
            anchors.fill: parent
            sourceComponent: themeWheel
            opacity: 1 - root.depth
            visible: opacity > 0.001
        }

        // ---- carrossel de wallpapers ---------------------------------------

        Item {
            id: carousel

            anchors.fill: parent

            // recua quando os temas estão na frente
            scale: 1 - 0.08 * root.depth
            transformOrigin: Item.Center

            readonly property real gap: 32

            // distância entre centros: selecionado -> vizinho e vizinho -> próximo
            readonly property real firstStep: stage.cardWidth * (0.5 + 0.36) + gap
            readonly property real nextStep: stage.cardWidth * (0.36 + 0.29) + gap
            readonly property real limit: root.fadeEnd(root.wallCount, 2.3)

            Repeater {
                model: root.wallCount > 0 ? root.slotCount : 0

                delegate: Item {
                    id: card

                    required property int index

                    readonly property int slot: root.slotFor(index, root.wallPos)
                    readonly property real d: slot - root.wallPos
                    readonly property real ad: Math.abs(d)
                    readonly property real near: 1 - Math.min(ad, 1)
                    readonly property var wallpaper: root.wallpapers[root.wrap(slot, root.wallCount)]
                    readonly property bool active: wallpaper && wallpaper.path === root.currentWallpaper

                    // quanto este card está "em foco" (centro e wallpapers na frente)
                    readonly property real focusAmount: near * (1 - 0.6 * root.depth)

                    width: stage.cardWidth
                    height: stage.cardHeight

                    x: stage.cx - width / 2
                       + Math.sign(d) * (carousel.firstStep * Math.min(ad, 1)
                                         + carousel.nextStep * Math.max(ad - 1, 0))
                    y: stage.cy - height / 2

                    scale: 1 - 0.28 * Math.min(ad, 1) - 0.14 * Math.max(ad - 1, 0)
                    opacity: root.clamp01((carousel.limit - ad) / 0.5)
                    visible: opacity > 0.001
                    z: 100 - ad * 10

                    // perspectiva sutil: os laterais viram para o centro
                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -root.clamp(card.d, -1.6, 1.6) * 14
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 24
                        blur: 0.3 * Math.min(card.ad, 1) + 0.25 * root.depth
                        brightness: -0.3 * Math.min(card.ad, 1) - 0.18 * root.depth
                        saturation: -0.2 * Math.min(card.ad, 1)
                        shadowEnabled: true
                        shadowColor: Qt.tint("#000000", Qt.alpha(ui.primary, 0.7 * card.focusAmount))
                        shadowOpacity: 0.55
                        shadowBlur: 1.0
                        shadowVerticalOffset: 16 * (1 - card.focusAmount)
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 20
                        color: ui.surface

                        Image {
                            anchors.fill: parent
                            source: card.wallpaper ? card.wallpaper.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        // legenda sobre a imagem: nome e posição
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * 0.32

                            opacity: card.near
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.7) }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 22
                                anchors.right: counter.left
                                anchors.rightMargin: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16

                                text: card.wallpaper ? card.wallpaper.name : ""
                                elide: Text.ElideRight
                                color: "#FFFFFF"
                                font.family: Typo.family
                                font.pixelSize: Typo.size.large + 2
                                font.weight: Typo.weight.semibold
                            }

                            Text {
                                id: counter

                                anchors.right: parent.right
                                anchors.rightMargin: 22
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 18

                                text: (root.wrap(card.slot, root.wallCount) + 1) + " / " + root.wallCount
                                color: Qt.alpha("#FFFFFF", 0.75)
                                font.family: Typo.family
                                font.pixelSize: Typo.size.normal
                            }
                        }
                    }

                    // borda iluminada na cor primária do tema em prévia
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: "transparent"
                        border.width: 3
                        border.color: ui.primary
                        opacity: root.clamp01(1 - card.ad * 2)
                    }

                    // marca do wallpaper aplicado agora
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 16

                        visible: card.active
                        width: currentText.implicitWidth + 20
                        height: currentText.implicitHeight + 8
                        radius: height / 2
                        color: Qt.alpha(ui.background, 0.75)
                        border.width: 1
                        border.color: Qt.alpha(ui.primary, 0.6)

                        Text {
                            id: currentText

                            anchors.centerIn: parent
                            text: "● atual"
                            color: ui.primary
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small
                            font.weight: Typo.weight.medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.activeCarousel = "wallpapers";
                            root.wallTarget = card.slot;
                        }
                        onDoubleClicked: {
                            root.wallTarget = card.slot;
                            root.apply(true, true);
                        }
                    }
                }
            }
        }

        // roleta na frente dos wallpapers
        Loader {
            anchors.fill: parent
            sourceComponent: themeWheel
            opacity: root.depth
            visible: opacity > 0.001
        }

        // ---- mensagens de vazio --------------------------------------------

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.cy - stage.cardHeight / 2 - 80
            visible: root.themesLoaded && root.themeCount === 0
            text: "Nenhum tema em ~/hyprconf/Themes"
            color: ui.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.normal
        }

        Text {
            anchors.centerIn: parent
            visible: root.wallpapersLoaded && root.wallCount === 0
            text: "Nenhum wallpaper em ~/hyprconf/Wallpapers"
            color: ui.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.large
        }

        // ---- atalhos --------------------------------------------------------

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32

            spacing: 26
            z: 1000

            Repeater {
                model: [
                    { keys: "h  l", label: "wallpaper", carousel: "wallpapers" },
                    { keys: "j  k", label: "tema", carousel: "themes" },
                    { keys: "⏎", label: "aplicar", carousel: "" },
                    { keys: "w", label: "só wallpaper", carousel: "" },
                    { keys: "t", label: "só tema", carousel: "" },
                    { keys: "esc", label: "sair", carousel: "" }
                ]

                delegate: Row {
                    id: hint

                    required property var modelData
                    readonly property bool highlighted: modelData.carousel === root.activeCarousel

                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter

                        width: Math.max(height, keyText.implicitWidth + 14)
                        height: keyText.implicitHeight + 6
                        radius: 6
                        color: hint.highlighted ? Qt.alpha(ui.primary, 0.22) : Qt.alpha(ui.surface, 0.85)
                        border.width: 1
                        border.color: hint.highlighted ? ui.primary : Qt.alpha(ui.outline, 0.8)

                        Behavior on color { ColorAnimation { duration: 240 } }
                        Behavior on border.color { ColorAnimation { duration: 240 } }

                        Text {
                            id: keyText

                            anchors.centerIn: parent
                            text: hint.modelData.keys
                            color: hint.highlighted ? ui.primary : ui.text
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small
                            font.weight: Typo.weight.semibold
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hint.modelData.label
                        color: hint.highlighted ? ui.text : ui.muted
                        font.family: Typo.family
                        font.pixelSize: Typo.size.small
                    }
                }
            }
        }
    }
}
