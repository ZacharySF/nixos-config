import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.components
import qs.config
import qs.services

// Wi-Fi strength is always shown; Bluetooth, Tailscale, Mullvad, hotspot,
// USB and serial glyphs join it only while they have something to say.
// One popover for the whole cluster: toggles up top, then networks, paired
// devices, tailnet peers and plugged-in devices.
BarButton {
    id: root

    readonly property string wifiGlyph: {
        if (Connectivity.wired)
            return "lan";
        if (!Connectivity.wifiEnabled)
            return "wifi_off";
        if (Connectivity.wifiConnected)
            return Connectivity.wifiGlyph(Connectivity.wifiStrength);
        return "wifi_find";
    }

    active: pop.open
    tooltip: {
        const lines = [];
        if (Connectivity.wired)
            lines.push("Wired");
        if (!Connectivity.wifiEnabled)
            lines.push("Wi-Fi off");
        else if (Connectivity.wifiConnected)
            lines.push(`Wi-Fi: ${Connectivity.wifiNetwork.name} · ${Math.round(Connectivity.wifiStrength * 100)}%`);
        else
            lines.push(Connectivity.wifiConnecting ? "Wi-Fi: connecting" : "Wi-Fi: not connected");
        for (const d of Connectivity.btConnected)
            lines.push(`Bluetooth: ${d.name}${d.batteryAvailable ? " · " + Connectivity.batteryText(d) : ""}`);
        if (Connectivity.tailscaleRunning)
            lines.push(`Tailscale: ${Connectivity.tailscaleOnline.length} online${Connectivity.tailscaleExitNode ? " · exit node " + Connectivity.tailscaleExitNode.name : ""}`);
        if (Connectivity.mullvadConnected)
            lines.push(`Mullvad: ${Connectivity.mullvadRelay || Connectivity.mullvadLocation}`);
        if (Connectivity.hotspotActive)
            lines.push("Hotspot on");
        for (const p of Connectivity.serialPorts)
            lines.push(`Serial: /dev/${p.id}${p.name ? " · " + p.name : ""}`);
        if (Connectivity.usbFlash && Connectivity.usbDevices.length > 0)
            lines.push(`USB: ${Connectivity.usbDevices[Connectivity.usbDevices.length - 1].name}`);
        return lines.join("\n");
    }
    onClicked: pop.toggle()

    // Wi-Fi, with a dot while the tailnet is up (accent; warning while an
    // exit node routes all traffic).
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize

        Icon {
            anchors.centerIn: parent
            name: root.wifiGlyph
        }
        Rectangle {
            visible: Connectivity.tailscaleRunning
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -1
            anchors.topMargin: -1
            width: 7
            height: 7
            radius: 3.5
            color: Connectivity.tailscaleExitNode !== null ? Theme.warning : Theme.accent
            border.width: 1.5
            border.color: Theme.surfaceContainer
        }
    }


    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Connectivity.mullvadConnected || Connectivity.mullvadBusy
        name: "vpn_lock"
        opacity: Connectivity.mullvadBusy ? 0.5 : 1
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Connectivity.hotspotActive
        name: "wifi_tethering"
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Connectivity.usbFlash
        name: "usb"
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Connectivity.serialPorts.length > 0
        name: "cable"
    }

    Popover {
        id: pop

        target: root
        onOpenChanged: Connectivity.watching = open

        Column {
            id: body

            readonly property real tileWidth: (width - 6) / 2

            spacing: 4
            width: 320

            Item {
                width: parent.width
                height: 28

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connections"
                    strong: true
                    font.pixelSize: Theme.titleSize
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 160)
                    muted: true
                    text: Connectivity.wired ? "wired" : Connectivity.wifiConnected ? Connectivity.wifiNetwork.name : Connectivity.wifiEnabled ? "offline" : "Wi-Fi off"
                }
            }

            Grid {
                columns: 2
                spacing: 6

                Toggle {
                    width: body.tileWidth
                    icon: "wifi"
                    title: "Wi-Fi"
                    subtitle: !Connectivity.wifiEnabled ? "Off" : Connectivity.wifiConnected ? Connectivity.wifiNetwork.name : Connectivity.wifiConnecting ? "Connecting" : "Not connected"
                    checked: Connectivity.wifiEnabled
                    onToggled: Connectivity.setWifi(!Connectivity.wifiEnabled)
                }
                Toggle {
                    visible: Connectivity.btAvailable
                    width: body.tileWidth
                    icon: "bluetooth"
                    title: "Bluetooth"
                    subtitle: !Connectivity.btEnabled ? "Off" : Connectivity.btConnected.length > 0 ? Connectivity.btConnected.map(d => d.name).join(", ") : "On"
                    checked: Connectivity.btEnabled
                    busy: Connectivity.btBusy
                    onToggled: Connectivity.setBluetooth(!Connectivity.btEnabled)
                }
                Toggle {
                    visible: Connectivity.mullvadState !== ""
                    width: body.tileWidth
                    icon: "vpn_lock"
                    title: "Mullvad"
                    subtitle: Connectivity.mullvadConnected ? (Connectivity.mullvadLocation || Connectivity.mullvadRelay || "Connected") : Connectivity.mullvadState === "connecting" ? "Connecting" : Connectivity.mullvadState === "disconnecting" ? "Disconnecting" : Connectivity.mullvadState === "error" ? "Error" : "Off"
                    checked: Connectivity.mullvadConnected
                    busy: Connectivity.mullvadBusy
                    onToggled: Connectivity.setMullvad(!Connectivity.mullvadConnected)
                }
                Toggle {
                    visible: Connectivity.hotspotProfile !== null
                    width: body.tileWidth
                    icon: "wifi_tethering"
                    title: "Hotspot"
                    subtitle: Connectivity.hotspotProfile ? (Connectivity.hotspotActive ? "On · " : "") + Connectivity.hotspotProfile.name : ""
                    checked: Connectivity.hotspotActive
                    onToggled: Connectivity.setHotspot(!Connectivity.hotspotActive)
                }
            }

            Row {
                visible: Connectivity.vpnConflict
                spacing: 8
                topPadding: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "warning"
                    size: 16
                    fill: 1
                    color: Theme.warning
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: body.width - 24
                    text: "Tailscale exit node and Mullvad are both active"
                    font.pixelSize: Theme.smallSize + 1
                    color: Theme.warning
                }
            }

            // --- Wi-Fi networks ------------------------------------------
            SectionLabel {
                visible: wifiList.visible
                text: "Wi-Fi"
            }

            ListView {
                id: wifiList

                visible: Connectivity.wifiEnabled && count > 0
                width: parent.width
                height: Math.min(count, 6) * 36
                clip: true
                interactive: count > 6
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Connectivity.sortedNetworks
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: ListRow {
                    required property var modelData

                    readonly property bool secured: Connectivity.needsSecrets(modelData)

                    width: ListView.view.width
                    icon: Connectivity.wifiGlyph(modelData.signalStrength)
                    title: modelData.name
                    trailing: modelData.connected ? "connected" : modelData.stateChanging ? "connecting" : modelData.known ? "saved" : secured ? "" : "open"
                    trailingIcon: !modelData.connected && !modelData.known && secured ? "lock" : ""
                    highlighted: modelData.connected
                    interactive: !modelData.connected && (modelData.known || !secured)
                    onClicked: Connectivity.connectWifi(modelData)
                }
            }

            // --- Bluetooth -------------------------------------------------
            SectionLabel {
                visible: Connectivity.btEnabled && Connectivity.btDevices.length > 0
                text: "Bluetooth"
            }

            Repeater {
                model: ScriptModel {
                    values: Connectivity.btEnabled ? Connectivity.btDevices : []
                    comparisonMode: ObjectComparison.Identity
                }

                delegate: ListRow {
                    required property var modelData

                    width: body.width
                    icon: Connectivity.btGlyph(modelData)
                    title: modelData.name
                    trailing: modelData.connected ? (Connectivity.batteryText(modelData) || "connected") : modelData.state === BluetoothDeviceState.Connecting ? "connecting" : modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting" : ""
                    highlighted: modelData.connected
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }

            // --- Tailnet ---------------------------------------------------
            SectionLabel {
                visible: Connectivity.tailscaleRunning
                text: "Tailnet"
            }

            ListRow {
                visible: Connectivity.tailscaleRunning && Connectivity.tailscaleExitNode !== null
                width: body.width
                icon: "alt_route"
                iconColor: Theme.accent
                title: "Exit node: " + (Connectivity.tailscaleExitNode?.name ?? "")
                interactive: false
            }

            Repeater {
                model: ScriptModel {
                    values: Connectivity.tailscaleRunning ? Connectivity.tailscaleOnline : []
                    objectProp: "id"
                }

                delegate: ListRow {
                    required property var modelData

                    width: body.width
                    icon: {
                        const os = modelData.os.toLowerCase();
                        if (os === "ios")
                            return "phone_iphone";
                        if (os === "android")
                            return "smartphone";
                        if (os === "windows")
                            return "desktop_windows";
                        if (os === "macos")
                            return "laptop";
                        if (os === "linux")
                            return "computer";
                        return "devices";
                    }
                    title: modelData.name
                    trailing: modelData.exitNode ? "exit node" : modelData.exitNodeOption ? "offers exit" : modelData.active ? "active" : ""
                    interactive: false

                    // Online dot on the device glyph.
                    Rectangle {
                        x: 8 + 13
                        y: parent.height / 2 + 3
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.success
                        border.width: 1.5
                        border.color: Theme.panelSolid
                    }
                }
            }

            Label {
                visible: Connectivity.tailscaleRunning && Connectivity.tailscalePeers.length > Connectivity.tailscaleOnline.length
                leftPadding: 8
                muted: true
                font.pixelSize: Theme.smallSize
                text: {
                    const n = Connectivity.tailscalePeers.length - Connectivity.tailscaleOnline.length;
                    return n === 1 ? "1 peer offline" : `${n} peers offline`;
                }
            }

            // --- Serial / USB ----------------------------------------------
            SectionLabel {
                visible: Connectivity.serialPorts.length > 0 || Connectivity.usbDevices.length > 0
                text: "Devices"
            }

            Repeater {
                model: ScriptModel {
                    values: Connectivity.serialPorts
                    objectProp: "id"
                }

                delegate: ListRow {
                    required property var modelData

                    width: body.width
                    icon: "cable"
                    title: "/dev/" + modelData.id
                    subtitle: modelData.name
                    interactive: false
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Connectivity.usbDevices
                    objectProp: "id"
                }

                delegate: ListRow {
                    required property var modelData

                    width: body.width
                    icon: "usb"
                    title: modelData.name
                    subtitle: modelData.detail
                    interactive: false
                }
            }
        }
    }
}
