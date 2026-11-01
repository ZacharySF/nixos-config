pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Which MPRIS player the bar should show.
//
// Eligible: has a title, is not a sub-30 s clip (notification sounds, ads),
// and has not been paused for more than ten minutes. The most recently
// started player wins unless the user picked another one. `focused` is true
// while the shown player's own window has keyboard focus, so the bar can
// step aside; the owner is matched by the pid behind the player's bus name
// (looked up once per player) with app-id/identity heuristics as fallback.
Singleton {
    id: root

    readonly property int pausedLimit: 10 * 60 * 1000

    property var entries: []
    property var chosen: null
    // Coarse clock for the paused-too-long rule; ticks only while a player is paused.
    property real now: Date.now()

    readonly property var eligible: entries.filter(e => e.eligible).sort((a, b) => b.playedAt - a.playedAt)
    readonly property var active: (chosen && chosen.eligible) ? chosen : (eligible[0] ?? null)
    readonly property MprisPlayer player: active?.player ?? null
    readonly property bool focused: active !== null && ownsFocused(active)

    function choose(entry) {
        chosen = entry;
    }

    function ownsFocused(entry) {
        const win = Niri.focusedWindow;
        if (!win)
            return false;
        if (entry.pid > 0 && win.pid === entry.pid)
            return true;
        const appId = (win.app_id ?? "").toLowerCase();
        if (appId === "")
            return false;
        const tail = appId.split(".").pop();
        const p = entry.player;
        const entryId = (p.desktopEntry ?? "").toLowerCase();
        const bus = p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance.*$/, "").toLowerCase();
        const candidates = [entryId, entryId.split(".").pop(), bus, (p.identity ?? "").toLowerCase()];
        return candidates.some(c => c !== "" && (c === appId || c === tail));
    }

    Instantiator {
        model: Mpris.players

        delegate: Scope {
            id: entry

            required property MprisPlayer modelData
            readonly property MprisPlayer player: modelData
            readonly property bool playing: player.playbackState === MprisPlaybackState.Playing
            property real playedAt: 0
            property real pausedAt: 0
            property int pid: 0
            readonly property bool eligible: {
                if (/playerctld/.test(player.dbusName) || player.trackTitle === "")
                    return false;
                if (player.lengthSupported && player.length > 0 && player.length < 30)
                    return false;
                return playing || pausedAt === 0 || root.now - pausedAt < root.pausedLimit;
            }

            function mark() {
                if (playing) {
                    playedAt = Date.now();
                    // A newly started player takes over from a manual pick.
                    if (root.chosen && root.chosen !== entry)
                        root.chosen = null;
                } else {
                    pausedAt = Date.now();
                }
            }

            onPlayingChanged: mark()
            Component.onCompleted: {
                mark();
                pidLookup.running = true;
            }

            Process {
                id: pidLookup

                command: ["busctl", "--user", "--timeout=2", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", entry.player.dbusName]
                stdout: StdioCollector {
                    onStreamFinished: entry.pid = parseInt(text.replace(/^u\s+/, "")) || 0
                }
            }
        }

        onObjectAdded: (index, object) => root.entries = root.entries.concat([object])
        onObjectRemoved: (index, object) => {
            root.entries = root.entries.filter(e => e !== object);
            if (root.chosen === object)
                root.chosen = null;
        }
    }

    Timer {
        running: root.entries.some(e => !e.playing)
        interval: 60 * 1000
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
