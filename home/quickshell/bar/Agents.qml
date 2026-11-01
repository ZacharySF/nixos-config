import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// OMP agent sessions (services/AgentSessions). Hidden without sessions. The
// glyph stays plain; state lives in the badge corner: a thin accent arc
// spins while a session works, a dot marks one waiting on the user
// (warning), finished out of sight (accent) or failed (error). The count
// appears from two sessions on. The popover lists every session; clicking
// one focuses its Tern window.
BarButton {
    id: root

    readonly property int working: AgentSessions.working
    readonly property int waiting: AgentSessions.waiting
    readonly property int errors: AgentSessions.errors
    readonly property int unseenDone: AgentSessions.unseenDone
    readonly property int attention: AgentSessions.attention
    readonly property string summary: {
        const parts = [];
        if (waiting > 0)
            parts.push(waiting === 1 ? "1 needs you" : `${waiting} need you`);
        if (working > 0)
            parts.push(`${working} working`);
        if (unseenDone > 0)
            parts.push(`${unseenDone} finished`);
        if (errors > 0)
            parts.push(`${errors} failed`);
        if (parts.length > 0)
            return parts.join(" · ");
        const n = AgentSessions.sessions.length;
        return n === 1 ? "1 idle OMP session" : `${n} idle OMP sessions`;
    }
    // One still dot, the same as Wi-Fi's: yellow needs you, red failed,
    // accent working or finished-unseen. Nothing animates, so a session that
    // works for hours costs no redraws.
    readonly property color badgeColor: waiting > 0 ? Theme.warning : errors > 0 ? Theme.error : Theme.accent
    readonly property bool badge: waiting > 0 || errors > 0 || working > 0 || unseenDone > 0

    visible: AgentSessions.sessions.length > 0
    active: pop.open
    tooltip: summary
    onClicked: pop.toggle()

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize

        Icon {
            anchors.centerIn: parent
            name: "motion_mode"
            // Dense glyph: dimmed so it does not outweigh the line icons;
            // the state badge carries the color.
            color: Theme.textMuted
        }

        Rectangle {
            visible: root.badge
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -1
            anchors.topMargin: -1
            width: 7
            height: 7
            radius: 3.5
            color: root.badgeColor
            border.width: 1.5
            border.color: Theme.surfaceContainer
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: AgentSessions.sessions.length > 1
        text: AgentSessions.sessions.length
    }

    Popover {
        id: pop

        target: root

        // Live elapsed times only while the list is on screen.
        SystemClock {
            id: clock

            enabled: pop.open
            precision: SystemClock.Seconds
        }

        Column {
            spacing: 2
            width: 320

            Item {
                width: parent.width
                height: 30

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Agents"
                    strong: true
                    font.pixelSize: Theme.titleSize
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 200)
                    text: root.summary
                    muted: true
                    font.pixelSize: Theme.smallSize
                }
            }

            Repeater {
                model: ScriptModel {
                    objectProp: "sessionId"
                    values: AgentSessions.sessions
                }

                delegate: ListRow {
                    id: row

                    required property var modelData
                    readonly property bool quiet: modelData.state === "idle" || (modelData.state === "done" && modelData.seen)

                    width: 320
                    icon: {
                        switch (modelData.state) {
                        case "working":
                            return "progress_activity";
                        case "waiting":
                            return "help";
                        case "done":
                            return "check_circle";
                        case "error":
                            return "error";
                        default:
                            return "pause_circle";
                        }
                    }
                    iconColor: {
                        switch (modelData.state) {
                        case "working":
                            return Theme.accent;
                        case "waiting":
                            return Theme.warning;
                        case "done":
                            return modelData.seen ? Theme.textMuted : Theme.accent;
                        case "error":
                            return Theme.error;
                        default:
                            return Theme.textMuted;
                        }
                    }
                    title: modelData.title
                    subtitle: AgentSessions.shortPath(modelData.cwd) + (modelData.state === "working" && modelData.tool ? ` · ${modelData.tool}` : "")
                    trailing: `${AgentSessions.stateLabel(modelData)} · ${AgentSessions.elapsed(clock.date.getTime() - modelData.since)}`
                    opacity: quiet ? 0.7 : 1
                    onClicked: {
                        AgentSessions.focus(modelData);
                        pop.open = false;
                    }
                }
            }
        }
    }
}
