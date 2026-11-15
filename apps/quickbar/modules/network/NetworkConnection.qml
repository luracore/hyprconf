import Quickshell
import QtQuick

Item {
    id: root

    visible: false

    property var commandRunner: null
    property var networkService: null

    property var wifiDevice: null
    property var savedWifi: []
    property var wifiNetworks: []

    property string busySsid: ""
    property string errorSsid: ""
    property string errorText: ""

    signal refreshRequested

    function run(args, callback) {
        if (commandRunner)
            commandRunner.run(args, callback);
    }

    function cleanError(text) {
        return text.trim().split("\n").pop().replace(/^Error:\s*/, "") || "falha desconhecida";
    }

    function setError(ssid, err) {
        errorText = cleanError(err);
        errorSsid = ssid;
    }

    function clearError() {
        errorSsid = "";
        errorText = "";
    }

    function finish(ssid, code, err, cleanup) {
        busySsid = "";

        if (code !== 0) {
            setError(ssid, err);

            if (cleanup)
                run(cleanup);
        }

        refreshRequested();
    }

    // Perfis salvos.
    function profilesFor(ssid) {
        return savedWifi.filter(p => p.ssid === ssid);
    }

    function savedProfile(ssid) {
        return profilesFor(ssid).sort((a, b) => b.timestamp - a.timestamp)[0] ?? null;
    }

    // Conexão com perfil conhecido.
    function connectKnown(ssid) {
        const profile = savedProfile(ssid);

        if (!profile) {
            setError(ssid, "nenhum perfil salvo para esta rede");
            return;
        }

        clearError();
        busySsid = ssid;

        run(["nmcli", "connection", "up", "uuid", profile.uuid], (code, out, err) => finish(ssid, code, err));
    }

    // Rede aberta ou com senha (WPA/WEP). hidden: rede oculta.
    function connectPsk(ssid, password, hidden) {
        clearError();
        busySsid = ssid;

        const args = ["nmcli", "device", "wifi", "connect", ssid];

        if (password !== "")
            args.push("password", password);

        if (hidden)
            args.push("hidden", "yes");

        if (wifiDevice)
            args.push("ifname", wifiDevice.device);

        // Mantém o comportamento original do nmcli.
        run(args, (code, out, err) => finish(ssid, code, err));
    }

    // UUID do perfil recém-criado.
    function addedConnectionUuid(out) {
        const match = out.match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\) successfully added\.\s*$/i);

        return match ? match[1] : "";
    }

    // Rede corporativa (WPA-Enterprise / 802.1X).
    function connectEnterprise(ssid, o) {
        clearError();
        busySsid = ssid;

        const props = ["wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", o.eap, "802-1x.phase2-auth", o.phase2, "802-1x.identity", o.identity, "802-1x.password", o.password];

        if (o.anonymous)
            props.push("802-1x.anonymous-identity", o.anonymous);

        if (o.caCert)
            props.push("802-1x.ca-cert", o.caCert.replace(/^~(?=\/|$)/, Quickshell.env("HOME")));

        if (o.domain)
            props.push("802-1x.domain-suffix-match", o.domain);

        if (o.hidden)
            props.push("802-11-wireless.hidden", "yes");

        const create = ["nmcli", "connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid].concat(wifiDevice ? ["ifname", wifiDevice.device] : []).concat(props);

        run(create, (code, out, err) => {
            if (code !== 0)
                return finish(ssid, code, err);

            const uuid = addedConnectionUuid(out);

            if (uuid === "")
                return finish(ssid, 1, "perfil criado, mas não foi possível identificar o UUID");

            run(["nmcli", "connection", "up", "uuid", uuid], (upCode, upOut, upErr) => finish(ssid, upCode, upErr, ["nmcli", "connection", "delete", "uuid", uuid]));
        });
    }

    function disconnectWifi() {
        if (wifiDevice)
            run(["nmcli", "device", "disconnect", wifiDevice.device], () => refreshRequested());
    }

    // Esquecer redes.
    function markForgotten(ssid) {
        if (!networkService)
            return;

        networkService.savedWifi = networkService.savedWifi.filter(p => p.ssid !== ssid);

        networkService.wifiNetworks = networkService.wifiNetworks.map(n => n.ssid === ssid ? Object.assign({}, n, {
                known: false,
                inUse: false
            }) : n);
    }

    function deleteWifiProfiles(ssid, uuids, index, failure) {
        if (index >= uuids.length) {
            if (failure !== "")
                setError(ssid, failure);
            else
                markForgotten(ssid);

            refreshRequested();
            return;
        }

        run(["nmcli", "connection", "delete", "uuid", uuids[index]], (code, out, err) => {
            if (code !== 0 && failure === "")
                failure = err;

            deleteWifiProfiles(ssid, uuids, index + 1, failure);
        });
    }

    function forget(ssid) {
        clearError();

        if (!networkService)
            return;

        networkService.listWifiProfiles(profiles => {
            if (profiles === null) {
                setError(ssid, "não foi possível ler os perfis salvos");
                refreshRequested();
                return;
            }

            const uuids = profiles.filter(p => p.ssid === ssid).map(p => p.uuid);

            deleteWifiProfiles(ssid, uuids, 0, "");
        });
    }

    function setWifiEnabled(enabled) {
        run(["nmcli", "radio", "wifi", enabled ? "on" : "off"], () => refreshRequested());
    }

    function setWiredConnected(device, connected) {
        run(["nmcli", "device", connected ? "connect" : "disconnect", device], () => refreshRequested());
    }
}
