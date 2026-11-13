import QtQuick
import QtQuick.Layouts

import "../config/Sizes.js" as Sizes
import "../config/Typo.js" as Typo
import qs.config

// Painel de rede (aberto pelo módulo Network): cabo, Wi-Fi e formulários de
// conexão (senha comum, corporativa/802.1X e rede oculta).
PanelSurface {
    id: root

    required property var net          // o módulo Network (estado + ações)

    // ---- estado do painel -------------------------------------------------------

    property string expanded: ""       // ssid aberto na lista; "__hidden__" = rede oculta
    property string formFor: ""        // ssid com formulário de credenciais aberto

    property string fPassword: ""
    property bool fShowPassword: false
    property string fIdentity: ""
    property string fAnonymous: ""
    property string fEap: "peap"
    property string fPhase2: "mschapv2"
    property string fCaCert: ""
    property string fDomain: ""
    property string fHiddenSsid: ""
    property string fHiddenSecurity: "psk"     // open | psk | eap
    property bool fShowExtra: false

    readonly property string hiddenKey: "__hidden__"

    function resetForm() {
        fPassword = "";
        fShowPassword = false;
        fIdentity = "";
        fAnonymous = "";
        fEap = "peap";
        fPhase2 = "mschapv2";
        fCaCert = "";
        fDomain = "";
        fHiddenSsid = "";
        fHiddenSecurity = "psk";
        fShowExtra = false;
    }

    function toggle(ssid) {
        if (expanded === ssid) {
            expanded = "";
            formFor = "";
        } else {
            resetForm();
            expanded = ssid;
            formFor = "";
        }
    }

    function openForm(ssid) {
        resetForm();
        expanded = ssid;
        formFor = ssid;
    }

    function onRowClicked(n) {
        if (n.inUse || n.known)
            toggle(n.ssid);
        else if (!n.secured)
            net.connectPsk(n.ssid, "", false);
        else if (formFor === n.ssid)
            toggle(n.ssid);
        else
            openForm(n.ssid);
    }

    function canSubmit(enterprise, secured) {
        if (enterprise)
            return fIdentity.trim() !== "" && fPassword !== "";
        return !secured || fPassword !== "";
    }

    function submit(ssid, enterprise, hidden) {
        if (enterprise) {
            net.connectEnterprise(ssid, {
                identity: fIdentity.trim(),
                password: fPassword,
                eap: fEap,
                phase2: fPhase2,
                anonymous: fAnonymous.trim(),
                caCert: fCaCert.trim(),
                domain: fDomain.trim(),
                hidden: hidden
            });
        } else {
            net.connectPsk(ssid, fPassword, hidden);
        }
        formFor = "";
    }

    // falha de autenticação: reabre o formulário daquela rede
    Connections {
        target: root.net
        function onErrorSsidChanged() {
            if (root.net.errorSsid !== "" && root.net.errorNeedsCredentials && root.net.errorSsid !== root.hiddenKey) {
                const keepExpanded = root.expanded === root.hiddenKey;
                if (!keepExpanded)
                    root.openForm(root.net.errorSsid);
            }
        }
    }

    function securityLabel(n) {
        if (n.enterprise)
            return "Corporativa (802.1X)";
        if (!n.secured)
            return "Aberta";
        if (n.security.includes("WPA3"))
            return "WPA3";
        if (n.security.includes("WEP"))
            return "WEP";
        return "WPA2";
    }

    // ---- aparência --------------------------------------------------------------

    implicitWidth: 420

    closesOnEscape: false
    onEscapePressed: {
        if (root.expanded !== "") {
            root.expanded = "";
            root.formFor = "";
        } else {
            root.closeRequested();
        }
    }

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        PanelTitle {
            Layout.fillWidth: true
            text: "REDE"
        }

        PanelIconButton {
            visible: root.net.wifiDevice !== null && root.net.wifiEnabled
            icon: "󰑐"
            spinning: root.net.scanning
            onClicked: root.net.rescan()
        }

        PanelIconButton {
            icon: "󰒓"
            onClicked: root.net.openAdvanced()
        }
    }

    // portal cativo (login de hotel, aeroporto…)
    Rectangle {
        Layout.fillWidth: true
        visible: root.net.connectivity === "portal" || root.net.connectivity === "limited"
        implicitHeight: portalRow.implicitHeight + 16
        radius: Sizes.radius.normal
        color: Qt.alpha(Theme.colors.warning, 0.14)
        border.width: 1
        border.color: Qt.alpha(Theme.colors.warning, 0.5)

        RowLayout {
            id: portalRow
            anchors.fill: parent
            anchors.margins: 8
            anchors.leftMargin: 12
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: root.net.connectivity === "portal"
                    ? "Esta rede pede login no navegador"
                    : "Conectado, mas sem acesso à internet"
                wrapMode: Text.WordWrap
                color: Theme.colors.warning
                font.family: Typo.family
                font.pixelSize: Typo.size.small
            }

            PanelButton {
                visible: root.net.connectivity === "portal"
                text: "Abrir login"
                accent: Theme.colors.warning
                onClicked: root.net.openPortalLogin()
            }
        }
    }

    // ---- cabo -----------------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.net.wiredDevices.length > 0
        spacing: 6

        PanelTitle { text: "CABO" }

        Repeater {
            model: root.net.wiredDevices

            delegate: Rectangle {
                id: wired

                required property var modelData
                readonly property bool connected: modelData.state === "connected"
                readonly property bool unplugged: modelData.state === "unavailable"

                Layout.fillWidth: true
                implicitHeight: 48
                radius: Sizes.radius.normal
                color: connected ? Theme.selected : Theme.colors.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 12

                    Text {
                        text: wired.connected ? "󰈀" : "󰈂"
                        color: wired.connected ? Theme.colors.info : Theme.colors.muted
                        font.family: Typo.family
                        font.pixelSize: Typo.size.large
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: wired.connected ? wired.modelData.connection : "Desconectado"
                            elide: Text.ElideRight
                            color: Theme.colors.text
                            font.family: Typo.family
                            font.pixelSize: Typo.size.normal - 1
                            font.weight: Typo.weight.semibold
                        }

                        Text {
                            text: wired.modelData.device + "  ·  "
                                + (wired.connected ? "conectado" : wired.unplugged ? "cabo desconectado" : wired.modelData.state)
                            color: Theme.colors.muted
                            font.family: Typo.family
                            font.pixelSize: Typo.size.small - 1
                        }
                    }

                    PanelButton {
                        visible: !wired.unplugged
                        text: wired.connected ? "Desconectar" : "Conectar"
                        accent: wired.connected ? Theme.colors.muted : Theme.colors.primary
                        onClicked: root.net.setWiredConnected(wired.modelData.device, !wired.connected)
                    }
                }
            }
        }
    }

    // ---- Wi-Fi ------------------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            PanelTitle {
                Layout.fillWidth: true
                text: "WI-FI"
            }

            PanelSwitch {
                visible: root.net.wifiDevice !== null
                checked: root.net.wifiEnabled
                onToggled: root.net.setWifiEnabled(!root.net.wifiEnabled)
            }
        }

        Text {
            visible: root.net.wifiDevice === null
            text: "Nenhuma placa Wi-Fi encontrada"
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Text {
            visible: root.net.wifiDevice !== null && !root.net.wifiEnabled
            text: "Wi-Fi desligado"
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Text {
            visible: root.net.wifiDevice !== null && root.net.wifiEnabled && root.net.wifiNetworks.length === 0
            text: root.net.scanning ? "Procurando redes…" : "Nenhuma rede encontrada"
            color: Theme.colors.muted
            font.family: Typo.family
            font.pixelSize: Typo.size.small
        }

        Flickable {
            id: wifiScroll

            Layout.fillWidth: true
            visible: root.net.wifiDevice !== null && root.net.wifiEnabled && root.net.wifiNetworks.length > 0
            implicitHeight: Math.min(wifiColumn.implicitHeight, 560)
            contentHeight: wifiColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: wifiColumn

                width: wifiScroll.width
                spacing: 2

                Repeater {
                    model: root.net.wifiNetworks

                    delegate: ColumnLayout {
                        id: wifi

                        required property var modelData
                        readonly property var n: modelData
                        readonly property bool isExpanded: root.expanded === n.ssid
                        readonly property bool showForm: root.formFor === n.ssid
                        readonly property bool busy: root.net.busySsid === n.ssid
                        readonly property bool failed: root.net.errorSsid === n.ssid

                        Layout.fillWidth: true
                        spacing: 0

                        // rola a lista até mostrar a rede aberta (e o formulário) inteira
                        function reveal() {
                            Qt.callLater(() => {
                                const bottom = wifi.y + wifi.height;
                                const maxY = Math.max(0, wifiScroll.contentHeight - wifiScroll.height);
                                if (bottom > wifiScroll.contentY + wifiScroll.height)
                                    wifiScroll.contentY = Math.min(maxY, bottom - wifiScroll.height);
                                if (wifi.y < wifiScroll.contentY)
                                    wifiScroll.contentY = wifi.y;
                            });
                        }
                        onIsExpandedChanged: if (isExpanded) reveal()
                        onShowFormChanged: if (showForm) reveal()
                        onHeightChanged: if (isExpanded) reveal()

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Sizes.radius.normal
                            color: wifi.n.inUse ? Theme.selected
                                 : rowMouse.containsMouse || wifi.isExpanded ? Theme.hover
                                 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    text: root.net.signalIcon(wifi.n.signal)
                                    color: wifi.n.inUse ? Theme.colors.info : Theme.colors.text
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.large
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: wifi.n.ssid
                                        elide: Text.ElideRight
                                        color: Theme.colors.text
                                        font.family: Typo.family
                                        font.pixelSize: Typo.size.normal - 1
                                        font.weight: wifi.n.inUse ? Typo.weight.semibold : Typo.weight.regular
                                    }

                                    Text {
                                        text: wifi.busy ? "conectando…"
                                            : wifi.n.inUse ? "conectada"
                                            : wifi.n.known ? "salva  ·  " + root.securityLabel(wifi.n)
                                            : root.securityLabel(wifi.n)
                                        color: wifi.busy ? Theme.colors.warning : Theme.colors.muted
                                        font.family: Typo.family
                                        font.pixelSize: Typo.size.small - 1
                                    }
                                }

                                Text {
                                    visible: wifi.n.secured
                                    text: wifi.n.enterprise ? "󰒃" : "󰌾"
                                    color: Theme.colors.muted
                                    font.family: Typo.family
                                    font.pixelSize: Typo.size.normal
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !wifi.busy
                                onClicked: root.onRowClicked(wifi.n)
                            }
                        }

                        // detalhes: ações ou formulário
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.topMargin: 6
                            Layout.bottomMargin: 8
                            visible: wifi.isExpanded || wifi.failed
                            spacing: 8

                            PanelError {
                                visible: wifi.failed
                                text: root.net.errorText
                            }

                            RowLayout {
                                visible: wifi.isExpanded && !wifi.showForm && (wifi.n.inUse || wifi.n.known)
                                spacing: 6

                                PanelButton {
                                    text: wifi.n.inUse ? "Desconectar" : "Conectar"
                                    accent: wifi.n.inUse ? Theme.colors.muted : Theme.colors.primary
                                    onClicked: {
                                        if (wifi.n.inUse)
                                            root.net.disconnectWifi();
                                        else
                                            root.net.connectKnown(wifi.n.ssid);
                                    }
                                }

                                PanelButton {
                                    visible: wifi.n.secured
                                    text: "Trocar senha"
                                    accent: Theme.colors.muted
                                    onClicked: root.openForm(wifi.n.ssid)
                                }

                                PanelButton {
                                    text: "Esquecer"
                                    accent: Theme.colors.error
                                    onClicked: {
                                        root.net.forget(wifi.n.ssid);
                                        root.expanded = "";
                                    }
                                }
                            }

                            CredentialsForm {
                                visible: wifi.showForm
                                Layout.fillWidth: true
                                panel: root
                                enterprise: wifi.n.enterprise
                                onSubmitted: root.submit(wifi.n.ssid, wifi.n.enterprise, false)
                                onCancelled: root.toggle(wifi.n.ssid)
                            }
                        }
                    }
                }
            }
        }

        // rede oculta
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.net.wifiDevice !== null && root.net.wifiEnabled
            spacing: 8

            Text {
                text: root.expanded === root.hiddenKey ? "Rede oculta" : "Conectar a uma rede oculta…"
                color: hiddenMouse.containsMouse ? Theme.colors.text : Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small
                font.underline: hiddenMouse.containsMouse

                MouseArea {
                    id: hiddenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(root.hiddenKey)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.expanded === root.hiddenKey
                spacing: 8

                PanelField {
                    Layout.fillWidth: true
                    label: "Nome da rede (SSID)"
                    value: root.fHiddenSsid
                    onEdited: v => root.fHiddenSsid = v
                }

                PanelChips {
                    label: "Segurança"
                    options: [
                        { value: "open", label: "Aberta" },
                        { value: "psk", label: "Senha" },
                        { value: "eap", label: "Corporativa" }
                    ]
                    value: root.fHiddenSecurity
                    onPicked: v => root.fHiddenSecurity = v
                }

                PanelError {
                    visible: root.net.errorSsid !== "" && root.net.errorSsid === root.fHiddenSsid.trim()
                    text: root.net.errorText
                }

                CredentialsForm {
                    Layout.fillWidth: true
                    panel: root
                    enterprise: root.fHiddenSecurity === "eap"
                    needsPassword: root.fHiddenSecurity !== "open"
                    extraValid: root.fHiddenSsid.trim() !== ""
                    onSubmitted: root.submit(root.fHiddenSsid.trim(), root.fHiddenSecurity === "eap", true)
                    onCancelled: root.toggle(root.hiddenKey)
                }
            }
        }
    }

    // ---- componentes ------------------------------------------------------------

    // formulário de credenciais (senha comum ou corporativa). Os valores ficam
    // no painel (panel.f*), para sobreviverem a atualizações da lista.
    component CredentialsForm: ColumnLayout {
        id: form

        required property var panel
        property bool enterprise: false
        property bool needsPassword: true
        property bool extraValid: true
        signal submitted
        signal cancelled

        readonly property bool valid: extraValid && panel.canSubmit(enterprise, needsPassword)

        function trySubmit() {
            if (valid)
                submitted();
        }

        spacing: 8

        PanelField {
            Layout.fillWidth: true
            visible: form.enterprise
            label: "Usuário"
            placeholder: "ex.: matricula@faculdade.edu.br"
            value: form.panel.fIdentity
            onEdited: v => form.panel.fIdentity = v
            onAccepted: form.trySubmit()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: form.needsPassword
            spacing: 6

            PanelField {
                Layout.fillWidth: true
                label: "Senha"
                password: true
                revealed: form.panel.fShowPassword
                value: form.panel.fPassword
                onEdited: v => form.panel.fPassword = v
                onAccepted: form.trySubmit()
            }

            PanelIconButton {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 3
                icon: form.panel.fShowPassword ? "󰈉" : "󰈈"
                onClicked: form.panel.fShowPassword = !form.panel.fShowPassword
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: form.enterprise
            spacing: 8

            PanelChips {
                label: "Método"
                options: [
                    { value: "peap", label: "PEAP" },
                    { value: "ttls", label: "TTLS" }
                ]
                value: form.panel.fEap
                onPicked: v => form.panel.fEap = v
            }

            PanelChips {
                label: "Autenticação interna"
                options: [
                    { value: "mschapv2", label: "MSCHAPv2" },
                    { value: "pap", label: "PAP" },
                    { value: "gtc", label: "GTC" }
                ]
                value: form.panel.fPhase2
                onPicked: v => form.panel.fPhase2 = v
            }

            Text {
                text: form.panel.fShowExtra ? "Menos opções" : "Mais opções (certificado, domínio…)"
                color: extraMouse.containsMouse ? Theme.colors.text : Theme.colors.muted
                font.family: Typo.family
                font.pixelSize: Typo.size.small - 1
                font.underline: extraMouse.containsMouse

                MouseArea {
                    id: extraMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: form.panel.fShowExtra = !form.panel.fShowExtra
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: form.panel.fShowExtra
                spacing: 8

                PanelField {
                    Layout.fillWidth: true
                    label: "Identidade anônima (opcional)"
                    placeholder: "ex.: anonymous@faculdade.edu.br"
                    value: form.panel.fAnonymous
                    onEdited: v => form.panel.fAnonymous = v
                }

                PanelField {
                    Layout.fillWidth: true
                    label: "Certificado da CA (opcional)"
                    placeholder: "caminho, ex.: ~/Downloads/ca.pem"
                    value: form.panel.fCaCert
                    onEdited: v => form.panel.fCaCert = v
                }

                PanelField {
                    Layout.fillWidth: true
                    label: "Domínio do servidor (opcional)"
                    placeholder: "ex.: radius.faculdade.edu.br"
                    value: form.panel.fDomain
                    onEdited: v => form.panel.fDomain = v
                }
            }
        }

        RowLayout {
            spacing: 6

            PanelButton {
                text: "Conectar"
                enabledState: form.valid
                onClicked: form.trySubmit()
            }

            PanelButton {
                text: "Cancelar"
                accent: Theme.colors.muted
                onClicked: form.cancelled()
            }
        }
    }
}
