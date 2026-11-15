import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Item {
    id: root
    visible: false

    property var networkService: null

    property string busySsid: ""
    property string errorSsid: ""
    property string errorText: ""

    property var trackedNetwork: null
    property string pendingJson: ""

    function setError(ssid, msg) {
        busySsid = "";
        errorSsid = ssid;
        errorText = msg || "falha na conexão";
    }

    function clearError() {
        errorSsid = "";
        errorText = "";
    }

    function findNetwork(ssid) {
        if (!networkService)
            return null;
        return networkService.wifiNetworks.find(n => n.ssid === ssid)?.raw ?? null;
    }

    Connections {
        target: root.trackedNetwork

        function onConnectionFailed(reason) {
            const name = root.trackedNetwork?.name ?? root.busySsid;
            let msg = "falha ao conectar";
            if (reason === ConnectionFailReason.NoSecrets)
                msg = "senha incorreta ou ausente";
            else if (reason === ConnectionFailReason.Timeout)
                msg = "tempo esgotado";
            root.setError(name, msg);
            root.trackedNetwork = null;
        }

        function onConnectedChanged() {
            if (root.trackedNetwork?.connected) {
                root.busySsid = "";
                root.trackedNetwork = null;
            }
        }
    }

    // Cria perfil 802.1X ou Rede Oculta via libnm lendo JSON do stdin (zero vazamento em /proc)
    Process {
        id: nmHelper
        command: ["python3", "-c", "import sys, json, gi; gi.require_version('NM', '1.0'); from gi.repository import NM, GLib;" + "try:\n" + "  cfg = json.load(sys.stdin)\n" + "  ssid = str(cfg.get('ssid', '')).strip()\n" + "  if not ssid: raise ValueError('SSID inválido')\n" + "  c = NM.Client.new(None)\n" + "  con = NM.SimpleConnection.new()\n" + "  s_con = NM.SettingConnection.new()\n" + "  s_con.set_property(NM.SETTING_CONNECTION_ID, ssid)\n" + "  s_con.set_property(NM.SETTING_CONNECTION_TYPE, '802-11-wireless')\n" + "  s_con.set_property(NM.SETTING_CONNECTION_UUID, NM.utils_uuid_generate())\n" + "  con.add_setting(s_con)\n" + "  s_wifi = NM.SettingWireless.new()\n" + "  s_wifi.set_property(NM.SETTING_WIRELESS_SSID, GLib.Bytes.new(ssid.encode()))\n" + "  s_wifi.set_property(NM.SETTING_WIRELESS_HIDDEN, bool(cfg.get('hidden', False)))\n" + "  con.add_setting(s_wifi)\n" + "  mode = str(cfg.get('mode', 'psk'))\n" + "  if mode != 'open':\n" + "    s_sec = NM.SettingWirelessSecurity.new()\n" + "    if mode == 'eap':\n" + "      s_sec.set_property(NM.SETTING_WIRELESS_SECURITY_KEY_MGMT, 'wpa-eap')\n" + "      s_8021x = NM.Setting8021x.new()\n" + "      s_8021x.add_eap_method(str(cfg['eap']))\n" + "      s_8021x.set_property(NM.SETTING_802_1X_PHASE2_AUTH, str(cfg['phase2']))\n" + "      s_8021x.set_property(NM.SETTING_802_1X_IDENTITY, str(cfg['identity']))\n" + "      s_8021x.set_property(NM.SETTING_802_1X_PASSWORD, str(cfg['password']))\n" + "      if cfg.get('anonymous'): s_8021x.set_property(NM.SETTING_802_1X_ANONYMOUS_IDENTITY, str(cfg['anonymous']))\n" + "      if cfg.get('domain'): s_8021x.set_property(NM.SETTING_802_1X_DOMAIN_SUFFIX_MATCH, str(cfg['domain']))\n" + "      if cfg.get('caCert'): s_8021x.set_ca_cert(str(cfg['caCert']), NM.Setting8021xCKScheme.PATH)\n" + "      con.add_setting(s_8021x)\n" + "    else:\n" + "      s_sec.set_property(NM.SETTING_WIRELESS_SECURITY_KEY_MGMT, 'wpa-psk')\n" + "      s_sec.set_property(NM.SETTING_WIRELESS_SECURITY_PSK, str(cfg['password']))\n" + "    con.add_setting(s_sec)\n" + "  dev = next((d for d in c.get_devices() if d.get_device_type() == NM.DeviceType.WIFI), None)\n" + "  if not dev: raise RuntimeError('Dispositivo Wi-Fi não encontrado')\n" + "  loop = GLib.MainLoop()\n" + "  err = []\n" + "  def cb(client, res, _):\n" + "    try: client.add_and_activate_connection_finish(res)\n" + "    except Exception as e: err.append(str(e))\n" + "    finally: loop.quit()\n" + "  c.add_and_activate_connection_async(con, dev, None, None, cb, None)\n" + "  loop.run()\n" + "  if err: sys.stderr.write(err[0]); sys.exit(1)\n" + "except Exception as exc:\n" + "  sys.stderr.write(str(exc))\n" + "  sys.exit(1)"]

        onStarted: {
            nmHelper.write(root.pendingJson);
            nmHelper.stdinEnabled = false;
            root.pendingJson = "";
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "")
                    root.errorText = line;
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.setError(root.busySsid, root.errorText || "falha ao criar perfil");
            } else {
                root.busySsid = "";
                root.trackedNetwork = null;
            }
        }
    }

    function runHelper(ssid, payload) {
        if (nmHelper.running)
            return;
        clearError();
        busySsid = ssid;
        pendingJson = JSON.stringify(payload);
        nmHelper.stdinEnabled = true;
        nmHelper.running = true;
    }

    function connectKnown(ssid) {
        const net = findNetwork(ssid);
        if (!net) {
            setError(ssid, "rede não encontrada");
            return;
        }
        clearError();
        busySsid = ssid;
        trackedNetwork = net;
        net.connect();
    }

    function connectPsk(ssid, password, hidden) {
        if (hidden) {
            runHelper(ssid, {
                ssid: ssid,
                mode: password !== "" ? "psk" : "open",
                password: password,
                hidden: true
            });
            return;
        }

        const net = findNetwork(ssid);
        if (!net) {
            setError(ssid, "rede não encontrada");
            return;
        }

        clearError();
        busySsid = ssid;
        trackedNetwork = net;

        if (password !== "")
            net.connectWithPsk(password);
        else
            net.connect();
    }

    function connectEnterprise(ssid, options) {
        const certPath = options.caCert ? options.caCert.replace(/^~(?=\/|$)/, Quickshell.env("HOME")) : "";

        runHelper(ssid, {
            ssid: ssid,
            mode: "eap",
            eap: options.eap,
            phase2: options.phase2,
            identity: options.identity,
            password: options.password,
            anonymous: options.anonymous,
            caCert: certPath,
            domain: options.domain,
            hidden: options.hidden
        });
    }

    function disconnectWifi() {
        const active = networkService?.activeWifi?.raw;
        if (active)
            active.disconnect();
    }

    function forget(ssid) {
        clearError();
        const net = findNetwork(ssid);
        if (net)
            net.forget();
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled;
    }

    function setWiredConnected(deviceName, connected) {
        const wired = networkService?.wiredDevices.find(d => d.device === deviceName);
        if (!wired || !wired.raw?.network)
            return;

        if (connected)
            wired.raw.network.connect();
        else
            wired.raw.network.disconnect();
    }
}
