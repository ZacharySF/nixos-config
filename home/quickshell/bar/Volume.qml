import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// Output volume. Scroll nudges it through swayosd (same OSD as the media
// keys), middle-click mutes, click opens sound + display controls: default
// sink/source, per-app volumes, microphone, brightness and night light.
BarButton {
    id: root

    readonly property int percent: Audio.percent
    readonly property bool muted: Audio.muted
    readonly property string sinkName: Audio.sink ? Audio.label(Audio.sink) : ""

    active: pop.open
    tooltip: Audio.sink ? (muted ? `${sinkName} · muted` : `${sinkName} · ${percent}%`) : ""
    onClicked: pop.toggle()
    onMiddleClicked: Audio.toggleMute()
    onRightClicked: Audio.toggleMute()
    onScrolled: delta => Audio.setVolume(Audio.volume + (delta > 0 ? 0.05 : -0.05))

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.muted ? "volume_off" : root.percent === 0 ? "volume_mute" : root.percent < 50 ? "volume_down" : "volume_up"
        color: root.muted ? Theme.error : Theme.text
    }

    // --- Backlight: sysfs read, brightnessctl write, polled only while open.
    QtObject {
        id: backlight

        readonly property int max: parseInt(maxFile.text()) || 0
        readonly property int raw: parseInt(curFile.text()) || 0
        readonly property real level: max > 0 ? raw / max : 0
        // Slider position while a write is in flight, so dragging feels live.
        property real pending: -1
        property bool dirty: false

        function request(v) {
            pending = Math.max(0.01, Math.min(1, v));
            dirty = true;
            if (!setter.running)
                flush();
        }

        function flush() {
            dirty = false;
            setter.command = ["brightnessctl", "-q", "set", `${Math.round(pending * 100)}%`];
            setter.running = true;
        }
    }

    FileView {
        id: curFile

        path: "/sys/class/backlight/intel_backlight/brightness"
    }

    FileView {
        id: maxFile

        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }

    Process {
        id: setter

        onExited: {
            if (backlight.dirty) {
                backlight.flush();
            } else {
                backlight.pending = -1;
                curFile.reload();
            }
        }
    }

    Timer {
        running: pop.open
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: curFile.reload()
    }

    // --- Night light: the wlsunset user unit; checked when opened and after a toggle.
    QtObject {
        id: nightlight

        property bool on: false
        property bool busy: false

        function check() {
            status.running = true;
        }

        function toggle() {
            busy = true;
            switcher.command = ["systemctl", "--user", on ? "stop" : "start", "wlsunset.service"];
            switcher.running = true;
        }
    }

    Process {
        id: status

        command: ["systemctl", "--user", "is-active", "wlsunset.service"]
        stdout: StdioCollector {
            onStreamFinished: nightlight.on = text.trim() === "active"
        }
    }

    Process {
        id: switcher

        onExited: {
            nightlight.busy = false;
            nightlight.check();
        }
    }

    component DeviceRow: ListRow {
        required property PwNode modelData
        required property bool current

        width: 300
        title: Audio.label(modelData)
        highlighted: current
        trailingIcon: current ? "check" : ""
    }

    Popover {
        id: pop

        target: root
        onOpenChanged: if (open) nightlight.check()

        Column {
            width: 300
            spacing: 4

            SectionLabel {
                text: "Output"
            }
            // Same layout as the microphone row: a mute button that does not
            // depend on middle-click (touchpads).
            Row {
                width: parent.width
                spacing: 6

                Slider {
                    width: parent.width - 34 - parent.spacing
                    icon: root.muted ? "volume_off" : "volume_up"
                    value: Math.min(1, Audio.volume)
                    fillColor: root.muted ? Theme.outlineVariant : Theme.accent
                    onMoved: v => Audio.setVolume(v)
                }
                BarButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    tooltip: root.muted ? "Unmute" : "Mute"
                    onClicked: Audio.toggleMute()

                    Icon {
                        name: root.muted ? "volume_off" : "volume_up"
                        size: 18
                        color: root.muted ? Theme.error : Theme.text
                    }
                }
            }
            Repeater {
                model: ScriptModel {
                    // HDMI/DP sinks exist for every connector; list them only
                    // when an external display is attached or one is in use.
                    values: Audio.sinks.filter(n => n === Audio.sink || !/hdmi|displayport/i.test(n.name) || Quickshell.screens.length > 1)
                    objectProp: "id"
                }

                delegate: DeviceRow {
                    current: modelData === Audio.sink
                    icon: {
                        const n = modelData.name.toLowerCase();
                        return n.includes("hdmi") ? "tv" : n.includes("bluez") || n.includes("headset") || n.includes("headphone") ? "headphones" : "speaker";
                    }
                    onClicked: Audio.setDefaultSink(modelData)
                }
            }

            SectionLabel {
                visible: Audio.playbackStreams.length > 0
                text: "Apps"
            }
            Repeater {
                model: ScriptModel {
                    values: Audio.playbackStreams
                    objectProp: "id"
                }

                delegate: Item {
                    id: app

                    required property PwNode modelData
                    readonly property string iconName: Audio.streamIcon(modelData)
                    readonly property string iconSource: iconName !== "" && Quickshell.hasThemeIcon(iconName) ? Quickshell.iconPath(iconName) : ""

                    width: 300
                    height: 28

                    Image {
                        id: appIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        sourceSize.width: 36
                        sourceSize.height: 36
                        source: app.iconSource
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !appIcon.visible
                        name: "music_note"
                        size: 17
                    }
                    Label {
                        id: appName

                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        text: Audio.streamName(app.modelData)
                    }
                    Slider {
                        anchors.left: appName.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        step: 0.05
                        value: app.modelData.audio?.volume ?? 0
                        fillColor: app.modelData.audio?.muted ? Theme.outlineVariant : Theme.secondary
                        onMoved: v => {
                            if (app.modelData.audio)
                                app.modelData.audio.volume = v;
                        }
                    }
                }
            }

            SectionLabel {
                text: "Input"
            }
            Row {
                width: parent.width
                spacing: 6

                Slider {
                    width: parent.width - 34 - parent.spacing
                    icon: Audio.micMuted ? "mic_off" : "mic"
                    value: Math.min(1, Audio.micVolume)
                    fillColor: Audio.micMuted ? Theme.outlineVariant : Theme.accent
                    enabled: Audio.source !== null
                    onMoved: v => Audio.setMicVolume(v)
                }
                BarButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    tooltip: Audio.micMuted ? "Unmute microphone" : "Mute microphone"
                    onClicked: Audio.toggleMicMute()

                    Icon {
                        name: Audio.micMuted ? "mic_off" : "mic"
                        size: 18
                        color: Audio.micMuted ? Theme.error : Theme.text
                    }
                }
            }
            Repeater {
                model: ScriptModel {
                    values: Audio.sources.length > 1 ? Audio.sources : (Audio.source ? [Audio.source] : [])
                    objectProp: "id"
                }

                delegate: DeviceRow {
                    current: modelData === Audio.source
                    interactive: Audio.sources.length > 1
                    icon: "mic"
                    onClicked: Audio.setDefaultSource(modelData)
                }
            }

            SectionLabel {
                text: "Display"
            }
            Slider {
                width: parent.width
                icon: "brightness_6"
                step: 0.05
                value: backlight.pending >= 0 ? backlight.pending : backlight.level
                enabled: backlight.max > 0
                onMoved: v => backlight.request(v)
            }
            Item {
                width: 1
                height: 2
            }
            Toggle {
                width: parent.width
                icon: "nightlight"
                title: "Night light"
                subtitle: nightlight.on ? "Warm after sunset" : "Off"
                checked: nightlight.on
                busy: nightlight.busy
                onToggled: if (!nightlight.busy) nightlight.toggle()
            }
        }
    }
}
