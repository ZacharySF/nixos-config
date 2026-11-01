pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// Everything the Connections item shows, in one place: Wi-Fi and wired
// (Quickshell.Networking), Bluetooth (Quickshell.Bluetooth), Tailscale and
// Mullvad (their CLIs), the NetworkManager hotspot profile, and plugged-in
// serial/USB devices (udev events).
//
// Event-driven where an event source exists (NetworkManager, BlueZ, udev,
// `mullvad status listen`). Tailscale has no event stream, so it is polled:
// every 10 s while it is running or the popover is open, every 60 s while
// the daemon answers but is stopped, and not at all once the CLI fails.
Singleton {
    id: root

    // Set by the popover; enables Wi-Fi scanning and faster Tailscale polls.
    property bool watching: false

    // --- Wi-Fi / wired -----------------------------------------------------
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.filter(n => n.name !== "") : []
    readonly property var wifiNetwork: wifiNetworks.find(n => n.connected) ?? null
    readonly property bool wifiConnected: wifiNetwork !== null
    readonly property bool wifiConnecting: wifiDevice ? wifiDevice.state === ConnectionState.Connecting : false
    readonly property real wifiStrength: wifiNetwork ? wifiNetwork.signalStrength : 0
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property bool hotspotActive: wifiDevice ? wifiDevice.mode === WifiDeviceMode.AccessPoint : false
    // First NetworkManager profile in access-point mode, or null.
    property var hotspotProfile: null

    // Networks for the popover: connected first, then saved, then by signal
    // level (the glyph steps, so a scan does not reshuffle the list), then
    // by name.
    readonly property var sortedNetworks: wifiNetworks.slice().sort((a, b) => {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        if (a.known !== b.known)
            return a.known ? -1 : 1;
        const la = wifiLevel(a.signalStrength), lb = wifiLevel(b.signalStrength);
        return la !== lb ? lb - la : a.name.localeCompare(b.name);
    })

    // 0..4 bars, following NetworkManager's own strength steps.
    function wifiLevel(strength) {
        if (strength >= 0.8)
            return 4;
        if (strength >= 0.55)
            return 3;
        if (strength >= 0.3)
            return 2;
        if (strength >= 0.05)
            return 1;
        return 0;
    }

    function wifiGlyph(strength) {
        // Arc glyphs (not the filled signal wedges) so Wi-Fi matches the
        // outline icon set used across the bar.
        return ["wifi_1_bar", "wifi_1_bar", "wifi_2_bar", "wifi", "wifi"][wifiLevel(strength)];
    }

    function needsSecrets(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function setWifi(on) {
        Networking.wifiEnabled = on;
    }

    // Known and open networks connect directly. An unknown secured network
    // needs a password prompt the bar does not have, so it is left alone.
    function connectWifi(network) {
        if (network.connected || network.stateChanging)
            return;
        if (network.known || !needsSecrets(network))
            network.connect();
    }

    function setHotspot(on) {
        if (!hotspotProfile)
            return;
        Quickshell.execDetached(["nmcli", "connection", on ? "up" : "down", "uuid", hotspotProfile.uuid]);
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.watching && root.wifiEnabled
        when: root.wifiDevice !== null
    }

    // Hotspot profiles are rare and change rarely: looked up at start and
    // whenever the popover opens.
    onWatchingChanged: {
        if (watching) {
            hotspotLookup.running = true;
            devices.running = true;
            tailscalePoll.running = true;
        }
    }

    Process {
        id: hotspotLookup

        running: true
        command: ["nmcli", "-g", "UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const uuids = text.split("\n").filter(l => l.endsWith(":802-11-wireless")).map(l => l.split(":")[0]);
                if (uuids.length === 0) {
                    root.hotspotProfile = null;
                    return;
                }
                hotspotDetails.command = ["nmcli", "-t", "-f", "connection.id,connection.uuid,802-11-wireless.mode", "connection", "show"].concat(uuids);
                hotspotDetails.running = true;
            }
        }
    }

    Process {
        id: hotspotDetails

        stdout: StdioCollector {
            onStreamFinished: {
                let found = null;
                for (const block of text.split("\n\n")) {
                    const fields = {};
                    for (const line of block.split("\n")) {
                        const i = line.indexOf(":");
                        if (i > 0)
                            fields[line.slice(0, i)] = line.slice(i + 1);
                    }
                    if (fields["802-11-wireless.mode"] === "ap") {
                        found = {
                            name: fields["connection.id"],
                            uuid: fields["connection.uuid"]
                        };
                        break;
                    }
                }
                root.hotspotProfile = found;
            }
        }
    }

    // --- Bluetooth ---------------------------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: btAdapter !== null
    readonly property bool btEnabled: btAdapter?.enabled ?? false
    readonly property bool btBusy: btAdapter ? btAdapter.state === BluetoothAdapterState.Enabling || btAdapter.state === BluetoothAdapterState.Disabling : false
    readonly property var btDevices: Bluetooth.devices.values.filter(d => d.paired)
    readonly property var btConnected: btDevices.filter(d => d.connected)

    function setBluetooth(on) {
        if (btAdapter)
            btAdapter.enabled = on;
    }

    function btGlyph(device) {
        const icon = device.icon ?? "";
        if (icon.includes("headphones"))
            return "headphones";
        if (icon.includes("headset"))
            return "headset";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("gaming"))
            return "gamepad";
        if (icon.includes("audio") || icon.includes("speaker"))
            return "speaker";
        if (icon.includes("computer"))
            return "computer";
        return "bluetooth";
    }

    function batteryText(device) {
        return device.batteryAvailable ? `${Math.round(device.battery * 100)}%` : "";
    }

    // --- Tailscale ---------------------------------------------------------
    // "Running", "Stopped", "NeedsLogin", ... or "" while the CLI fails.
    property string tailscaleState: ""
    readonly property bool tailscaleRunning: tailscaleState === "Running"
    property var tailscaleSelf: null
    // [{ id, name, os, online, exitNode, exitNodeOption, active }]
    property var tailscalePeers: []
    readonly property var tailscaleOnline: tailscalePeers.filter(p => p.online)
    readonly property var tailscaleExitNode: tailscalePeers.find(p => p.exitNode) ?? null
    property bool tailscaleCliOk: true

    Process {
        id: tailscalePoll

        running: true
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st;
                try {
                    st = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.tailscaleState = st.BackendState ?? "";
                root.tailscaleSelf = st.Self ? {
                    name: st.Self.HostName,
                    dns: (st.Self.DNSName ?? "").replace(/\.$/, ""),
                    ips: st.Self.TailscaleIPs ?? []
                } : null;
                root.tailscalePeers = Object.values(st.Peer ?? {}).map(p => ({
                            id: p.ID,
                            name: p.HostName || (p.DNSName ?? "").split(".")[0],
                            os: p.OS ?? "",
                            online: p.Online === true,
                            exitNode: p.ExitNode === true,
                            exitNodeOption: p.ExitNodeOption === true,
                            active: p.Active === true
                        })).sort((a, b) => (a.online === b.online ? a.name.localeCompare(b.name) : a.online ? -1 : 1));
            }
        }
        // A non-zero exit means the daemon is unreachable: stop polling until
        // the popover asks again.
        onExited: code => {
            root.tailscaleCliOk = code === 0;
            if (code !== 0) {
                root.tailscaleState = "";
                root.tailscaleSelf = null;
                root.tailscalePeers = [];
            }
        }
    }

    Timer {
        interval: root.tailscaleRunning || root.watching ? 10000 : 60000
        running: root.tailscaleCliOk && (root.tailscaleRunning || root.watching || root.tailscaleState !== "")
        repeat: true
        onTriggered: tailscalePoll.running = true
    }

    // --- Mullvad -----------------------------------------------------------
    // "connected", "connecting", "disconnected", "disconnecting", "error",
    // or "" while the daemon is unreachable.
    property string mullvadState: ""
    readonly property bool mullvadConnected: mullvadState === "connected"
    readonly property bool mullvadBusy: mullvadState === "connecting" || mullvadState === "disconnecting"
    property string mullvadLocation: ""
    property string mullvadRelay: ""

    function setMullvad(on) {
        Quickshell.execDetached(["mullvad", on ? "connect" : "disconnect"]);
    }

    // `mullvad status listen` prints the current state and then one line per
    // change, so the tile and glyph follow the tunnel without polling.
    Process {
        id: mullvadListen

        running: true
        command: ["mullvad", "status", "-j", "listen"]
        stdout: SplitParser {
            onRead: line => {
                let st;
                try {
                    st = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.mullvadState = st.state ?? "";
                const loc = st.details?.location ?? null;
                root.mullvadLocation = loc ? [loc.city, loc.country].filter(s => s).join(", ") : "";
                root.mullvadRelay = loc?.hostname ?? "";
            }
        }
        onExited: {
            root.mullvadState = "";
            mullvadRetry.restart();
        }
    }

    Timer {
        id: mullvadRetry

        interval: 60000
        onTriggered: mullvadListen.running = true
    }

    readonly property bool vpnConflict: tailscaleExitNode !== null && mullvadConnected

    // --- Serial / USB ------------------------------------------------------
    // serialPorts: [{ id: "ttyACM0", name }]; usbDevices: [{ id, name, detail }]
    // (removable USB devices only; internal camera/fingerprint reader stay out).
    property var serialPorts: []
    property var usbDevices: []
    // True for 10 s after a USB device is plugged in.
    property bool usbFlash: false

    readonly property string deviceScript: `
for d in /sys/bus/usb/devices/*/; do
  [ -f "$d/idVendor" ] || continue
  v=$(cat "$d/idVendor"); [ "$v" = 1d6b ] && continue
  r=unknown; [ -f "$d/removable" ] && r=$(cat "$d/removable")
  printf 'usb\\t%s\\t%s\\t%s:%s\\t%s\\t%s\\n' "$(basename "$d")" "$r" "$v" "$(cat "$d/idProduct")" "$(cat "$d/manufacturer" 2>/dev/null)" "$(cat "$d/product" 2>/dev/null)"
done
for t in /sys/class/tty/ttyACM* /sys/class/tty/ttyUSB*; do
  [ -e "$t" ] || continue
  u=$(readlink -f "$t/device")
  while [ "$u" != / ] && [ ! -f "$u/idVendor" ]; do u=$(dirname "$u"); done
  printf 'tty\\t%s\\t%s\\t%s\\n' "$(basename "$t")" "$(basename "$u")" "$(cat "$u/product" 2>/dev/null)"
done
`

    Process {
        id: devices

        running: true
        command: ["sh", "-c", root.deviceScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const usb = [];
                const tty = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "usb" && f[2] !== "fixed")
                        usb.push({
                            id: f[1],
                            name: f[5] || f[4] || f[3],
                            detail: [f[4], f[3]].filter(s => s).join(" · ")
                        });
                    else if (f[0] === "tty")
                        tty.push({
                            id: f[1],
                            name: f[3] || f[2]
                        });
                }
                root.usbDevices = usb;
                root.serialPorts = tty;
            }
        }
    }

    // udev reports every interface of a device as well; one re-scan per burst.
    Timer {
        id: rescan

        interval: 400
        onTriggered: devices.running = true
    }

    Timer {
        id: usbFlashTimer

        interval: 10000
        onTriggered: root.usbFlash = false
    }

    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=tty", "--subsystem-match=usb"]
        stdout: SplitParser {
            onRead: line => {
                // "UDEV  [1234.56] add      /devices/.../usb1/1-1 (usb)"
                const m = line.match(/^UDEV\s+\[[\d.]+\]\s+(\w+)\s+(\S+)\s+\((\w+)\)/);
                if (!m)
                    return;
                const [, action, path, subsystem] = m;
                if (action !== "add" && action !== "remove")
                    return;
                rescan.restart();
                if (action === "add" && subsystem === "usb" && !path.split("/").pop().includes(":")) {
                    root.usbFlash = true;
                    usbFlashTimer.restart();
                }
            }
        }
    }
}
