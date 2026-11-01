import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Battery: level glyph + percent, and the live draw while on battery.
// Click: time estimate, health, a session charge graph
// and the pen's battery when it reports one.
BarButton {
    id: root

    readonly property int pct: Power.percent
    // Outline frame with a level bar inside (battery_android_frame_*), so
    // the battery matches the outline icons instead of a solid block.
    readonly property string glyph: {
        if (Power.full && Power.acOnline)
            return "power";
        if (Power.charging)
            return "battery_android_frame_bolt";
        if (Power.critical)
            return "battery_android_frame_alert";
        return pct >= 95 ? "battery_android_frame_full" : "battery_android_frame_" + Math.max(1, Math.min(6, Math.round(pct / 100 * 6)));
    }
    readonly property string summary: {
        if (Power.full)
            return Power.acOnline ? "Fully charged" : "Full";
        if (Power.charging)
            return Power.secondsLeft > 0 ? `Charging · ${Power.formatDuration(Power.secondsLeft)} to full` : "Charging";
        if (Power.discharging)
            return Power.secondsLeft > 0 ? `${Power.formatDuration(Power.secondsLeft)} left` : "Estimating…";
        return Power.status;
    }

    visible: Power.available
    active: pop.open
    tooltip: `${pct}% · ${summary}`
    onClicked: pop.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.glyph
        color: Power.critical ? Theme.error : Theme.text
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: `${root.pct}%`
        color: Power.critical ? Theme.error : Theme.text
    }

    Popover {
        id: pop

        target: root

        Column {
            width: 320
            spacing: 10

            Row {
                spacing: 10

                Label {
                    anchors.baseline: status.baseline
                    text: `${root.pct}%`
                    strong: true
                    font.pixelSize: 24
                }
                Label {
                    id: status

                    text: root.summary
                    muted: true
                }
            }


            // Session charge history: real samples, one per minute.
            Canvas {
                id: graph

                width: parent.width
                height: 64
                visible: Power.history.length > 1
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const h = Power.history;
                    const t0 = h[0].t, t1 = h[h.length - 1].t;
                    const span = Math.max(1, t1 - t0);
                    const x = p => (p.t - t0) / span * (width - 2) + 1;
                    const y = p => height - 2 - p.pct / 100 * (height - 4);
                    ctx.beginPath();
                    ctx.moveTo(x(h[0]), height);
                    for (const p of h)
                        ctx.lineTo(x(p), y(p));
                    ctx.lineTo(x(h[h.length - 1]), height);
                    ctx.closePath();
                    ctx.fillStyle = Theme.alpha(Theme.accent, 0.18);
                    ctx.fill();
                    ctx.beginPath();
                    h.forEach((p, i) => i === 0 ? ctx.moveTo(x(p), y(p)) : ctx.lineTo(x(p), y(p)));
                    ctx.strokeStyle = Theme.accent;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }

                Connections {
                    target: Power
                    function onHistoryChanged() {
                        graph.requestPaint();
                    }
                }
            }

            Column {
                width: parent.width

                ListRow {
                    width: parent.width
                    interactive: false
                    visible: Power.powerNow > 0
                    icon: "bolt"
                    title: "Power draw"
                    trailing: Power.formatWatts(Power.rate > 0 ? Power.rate : Power.powerNow)
                }
                ListRow {
                    width: parent.width
                    interactive: false
                    icon: "health_and_safety"
                    title: "Health"
                    trailing: Power.health > 0 ? `${Math.round(Power.health * 100)}% of ${Power.energyDesign.toFixed(0)} Wh` : "—"
                }
                ListRow {
                    width: parent.width
                    interactive: false
                    visible: Power.cycles >= 0
                    icon: "autorenew"
                    title: "Cycles"
                    trailing: `${Power.cycles}`
                }
                ListRow {
                    width: parent.width
                    interactive: false
                    visible: Power.penPresent && Power.penPercent >= 0
                    icon: "stylus"
                    title: "Pen"
                    trailing: `${Power.penPercent}%`
                }
            }
        }
    }
}
