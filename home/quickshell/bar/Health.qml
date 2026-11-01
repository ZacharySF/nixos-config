import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Always present so the popover (each metric with two minutes of history and
// the hungriest processes) is one click away. Calm: a muted gauge glyph.
// When a threshold trips (sustained CPU load, memory or swap pressure,
// package temperature, throttling, fan, low disk) it switches to the leading
// problem's glyph, tinted, with its value; the tooltip lists every reason.
BarButton {
    id: root

    // Leading reason: the most urgent kind wins.
    readonly property var order: ["temp", "throttle", "nvme", "disk", "mem", "swap", "zram", "cpu", "fan"]
    readonly property var lead: Vitals.reasons.slice().sort((a, b) => rank(a.key) - rank(b.key))[0] ?? null
    readonly property color tone: Vitals.severe ? Theme.error : Theme.warning

    function rank(key) {
        const i = order.indexOf(key.startsWith("disk") ? "disk" : key);
        return i < 0 ? order.length : i;
    }

    function glyph(key) {
        if (key.startsWith("disk"))
            return "hard_drive";
        switch (key) {
        case "temp":
        case "throttle":
            return "device_thermostat";
        case "nvme":
            return "hard_drive";
        case "mem":
        case "swap":
        case "zram":
            return "memory";
        case "fan":
            return "mode_fan";
        default:
            return "speed";
        }
    }

    function shortValue(key) {
        if (key.startsWith("disk")) {
            const d = Vitals.disks.find(d => "disk" + d.mount === key);
            return d ? `${Math.round(d.free * 100)}% free` : "";
        }
        switch (key) {
        case "temp":
            return `${Vitals.cpuTemp}°`;
        case "nvme":
            return `${Vitals.nvmeTemp}°`;
        case "mem":
            return `${Math.round(Vitals.mem * 100)}%`;
        case "swap":
            return `${Math.round(Vitals.swap * 100)}%`;
        case "zram":
            return `${Math.round(Vitals.zram * 100)}%`;
        case "cpu":
            return `${Math.round(Vitals.cpu * 100)}%`;
        case "fan":
            return `${Vitals.fan}`;
        default:
            return "";
        }
    }

    // Narrow (portrait) screens: only when something is wrong.
    property bool narrow: false

    visible: !narrow || Vitals.tripped || pop.open
    active: pop.open
    tooltip: Vitals.tripped ? Vitals.reasons.map(r => r.text).join("\n") : `System OK · CPU ${Math.round(Vitals.cpu * 100)}% · RAM ${Math.round(Vitals.mem * 100)}% · ${Vitals.cpuTemp}°`
    onClicked: pop.toggle()

    // Tinted only on a genuine alert; otherwise muted like caffeine-off.
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.lead ? root.glyph(root.lead.key) : "monitor_heart"
        color: Vitals.tripped ? root.tone : Theme.textMuted
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: Vitals.tripped && text !== ""
        text: root.lead ? root.shortValue(root.lead.key) : ""
    }

    Popover {
        id: pop

        target: root
        onOpenChanged: Vitals.watching = open

        // One metric line: glyph, name, two-minute sparkline, current value.
        component Metric: Item {
            id: metric

            property string icon
            property string name
            property string value
            property var history: []
            property real max: 1
            property real threshold: 0
            property bool hot: false

            width: body.width
            height: 30

            Icon {
                id: metricIcon

                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                name: metric.icon
                size: 16
                color: metric.hot ? root.tone : Theme.textMuted
            }
            Label {
                anchors.left: metricIcon.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 74
                text: metric.name
            }
            Sparkline {
                anchors.right: valueLabel.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 118
                height: 20
                values: metric.history
                max: metric.max
                threshold: metric.threshold
                stroke: metric.hot ? root.tone : Theme.accent
            }
            Label {
                id: valueLabel

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 58
                horizontalAlignment: Text.AlignRight
                text: metric.value
                strong: metric.hot
                color: metric.hot ? root.tone : Theme.text
            }
        }

        component Sparkline: Canvas {
            id: canvas

            property var values: []
            property real max: 1
            property real threshold: 0
            property color stroke: Theme.accent

            onValuesChanged: requestPaint()
            onStrokeChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const step = w / (Vitals.historyLength - 1);
                const yOf = v => h - 1 - Math.max(0, Math.min(1, v / max)) * (h - 2);
                ctx.strokeStyle = Theme.alpha(Theme.outline, 0.35);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, h - 0.5);
                ctx.lineTo(w, h - 0.5);
                ctx.stroke();
                if (threshold > 0) {
                    ctx.strokeStyle = Theme.alpha(Theme.warning, 0.45);
                    ctx.setLineDash([2, 3]);
                    ctx.beginPath();
                    ctx.moveTo(0, yOf(threshold));
                    ctx.lineTo(w, yOf(threshold));
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
                const n = values.length;
                if (n < 2)
                    return;
                const x0 = w - (n - 1) * step;
                ctx.beginPath();
                for (let i = 0; i < n; i++) {
                    const x = x0 + i * step, y = yOf(values[i]);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.strokeStyle = stroke;
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "round";
                ctx.stroke();
                ctx.lineTo(w, h);
                ctx.lineTo(x0, h);
                ctx.closePath();
                ctx.fillStyle = Theme.alpha(stroke, 0.14);
                ctx.fill();
            }
        }

        Column {
            id: body

            spacing: 2
            width: 330

            Item {
                width: parent.width
                height: 28

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "System health"
                    strong: true
                    font.pixelSize: Theme.titleSize
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    muted: true
                    font.pixelSize: Theme.smallSize
                    text: Vitals.reasons.length === 1 ? "1 warning" : `${Vitals.reasons.length} warnings`
                }
            }

            Metric {
                icon: "speed"
                name: "CPU"
                value: `${Math.round(Vitals.cpu * 100)}%`
                history: Vitals.cpuHistory
                threshold: Vitals.cpuHigh
                hot: Vitals.reasons.some(r => r.key === "cpu")
            }
            Metric {
                icon: "memory"
                name: "Memory"
                value: `${Math.round(Vitals.mem * 100)}%`
                history: Vitals.memHistory
                threshold: Vitals.memHigh
                hot: Vitals.reasons.some(r => r.key === "mem")
            }
            Metric {
                icon: "swap_horiz"
                name: Vitals.zram > 0 ? "Swap · zram" : "Swap"
                value: Vitals.zram > 0 ? `${Math.round(Vitals.swap * 100)}% · ${Math.round(Vitals.zram * 100)}%` : `${Math.round(Vitals.swap * 100)}%`
                history: Vitals.swapHistory
                threshold: Vitals.swapHigh
                hot: Vitals.reasons.some(r => r.key === "swap" || r.key === "zram")
            }
            Metric {
                visible: Vitals.hasCpuTemp
                icon: "device_thermostat"
                name: Vitals.throttling ? "CPU · throttled" : "CPU temp"
                value: `${Vitals.cpuTemp} °C`
                history: Vitals.tempHistory
                max: 100
                threshold: Vitals.tempHigh
                hot: Vitals.reasons.some(r => r.key === "temp" || r.key === "throttle")
            }
            Metric {
                visible: Vitals.hasFan
                icon: "mode_fan"
                name: "Fan"
                value: `${Vitals.fan} rpm`
                history: Vitals.fanHistory
                max: Vitals.fanHigh * 1.25
                threshold: Vitals.fanHigh
                hot: Vitals.reasons.some(r => r.key === "fan")
            }
            Metric {
                visible: Vitals.hasNvmeTemp
                icon: "hard_drive"
                name: "NVMe"
                value: `${Vitals.nvmeTemp} °C`
                history: []
                hot: Vitals.reasons.some(r => r.key === "nvme")
            }

            Repeater {
                model: ScriptModel {
                    values: Vitals.disks
                    objectProp: "mount"
                }

                delegate: Metric {
                    required property var modelData

                    icon: "storage"
                    name: modelData.mount
                    value: `${Math.round(modelData.free * 100)}% free`
                    history: []
                    hot: Vitals.reasons.some(r => r.key === "disk" + modelData.mount)
                }
            }

            SectionLabel {
                visible: Vitals.processes.length > 0
                text: "Top processes"
            }

            Repeater {
                model: ScriptModel {
                    values: Vitals.processes
                    objectProp: "pid"
                }

                delegate: Item {
                    required property var modelData

                    width: body.width
                    height: 24

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: cpuCol.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                    }
                    Label {
                        id: cpuCol

                        anchors.right: memCol.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64
                        horizontalAlignment: Text.AlignRight
                        text: `${modelData.cpu.toFixed(1)}%`
                        font.pixelSize: Theme.smallSize + 1
                    }
                    Label {
                        id: memCol

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        horizontalAlignment: Text.AlignRight
                        text: `${modelData.mem.toFixed(1)}%`
                        muted: true
                        font.pixelSize: Theme.smallSize + 1
                    }
                }
            }

            Item {
                width: parent.width
                height: 6
            }

            ListRow {
                width: body.width
                icon: "monitoring"
                title: "Open system monitor"
                trailingIcon: "open_in_new"
                onClicked: {
                    Vitals.openMissionCenter();
                    pop.open = false;
                }
            }
        }
    }
}
