pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// OMP sessions, as published by the omp-bar-status extension
// (home/modules/omp-bar-status): one JSON line per top-level session in
// $XDG_RUNTIME_DIR/omp-bar/<sessionId>.json, replaced on every state change
// and removed at shutdown.
//
// The directory is watched with `inotifywait -m` (polled every 2 s only if
// inotifywait is unavailable) and re-read as a whole on each change: there
// are a handful of sessions at most. Sessions whose process is gone are
// dropped and their stale files removed; that /proc check runs every 5 s
// only while sessions exist. Sessions are replaced, never mutated in place.
Singleton {
    id: root

    readonly property string dir: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") ?? "";
        return runtime === "" ? "" : runtime + "/omp-bar";
    }
    readonly property bool available: dir !== ""
    readonly property string ternAppId: "so.stencil.tern"

    // Display order (needs you, failed, working, finished, idle). Each entry:
    // { sessionId, pid, ppid, ancestors, cwd, title, state, since, startedAt,
    //   tool, model, seen }. `seen` is only meaningful for state "done".
    property var sessions: []

    readonly property int working: sessions.filter(s => s.state === "working").length
    readonly property int waiting: sessions.filter(s => s.state === "waiting").length
    readonly property int errors: sessions.filter(s => s.state === "error").length
    readonly property int unseenDone: sessions.filter(s => s.state === "done" && !s.seen).length
    // Sessions worth a glance in the bar; seen "done" and idle ones are not.
    readonly property int attention: working + waiting + errors + unseenDone
    readonly property bool ternFocused: Niri.focusedWindow?.app_id === ternAppId

    // "<sessionId>@<since>" of finished sessions the user has looked at. A
    // session that finishes again gets a new `since`, hence a new key.
    property var seenKeys: ({})
    // False until the first scan: sessions already finished when the bar
    // starts are old news and count as seen.
    property bool primed: false
    property bool rescan: false

    readonly property var ternWindows: Niri.windowList.filter(w => w.app_id === ternAppId)

    // The Tern window that hosts the session: the one whose pid is in the
    // session's parent chain, otherwise the only / first Tern window.
    function ternWindowFor(s) {
        const own = ternWindows.find(w => (s.ancestors ?? []).indexOf(w.pid) >= 0);
        return own ?? ternWindows[0] ?? null;
    }

    function focus(s) {
        const w = ternWindowFor(s);
        if (w)
            Niri.focusWindow(w.id);
    }

    // Whether the user is looking at this session's terminal right now.
    function lookingAt(s) {
        const w = Niri.focusedWindow;
        if (!w || w.app_id !== ternAppId)
            return false;
        const own = ternWindows.find(t => (s.ancestors ?? []).indexOf(t.pid) >= 0);
        return !own || own.id === w.id;
    }

    function shortPath(p) {
        const home = Quickshell.env("HOME") ?? "";
        if (home !== "" && (p === home || p.startsWith(home + "/")))
            return "~" + p.slice(home.length);
        return p;
    }

    function stateLabel(s) {
        switch (s.state) {
        case "working":
            return "working";
        case "waiting":
            return "needs you";
        case "done":
            return "done";
        case "error":
            return "failed";
        default:
            return "idle";
        }
    }

    // Compact duration: 42s, 5m, 1h 12m, 3h.
    function elapsed(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        if (s < 60)
            return `${s}s`;
        const m = Math.floor(s / 60);
        if (m < 60)
            return `${m}m`;
        const h = Math.floor(m / 60);
        return h < 10 ? `${h}h ${m % 60}m` : `${h}h`;
    }

    function seenKey(s) {
        return `${s.sessionId}@${s.since}`;
    }

    // --- Directory scan ------------------------------------------------------
    function scan() {
        if (!available)
            return;
        if (scanner.running) {
            rescan = true;
            return;
        }
        scanner.running = true;
    }

    function ingest(text) {
        const parsed = [];
        for (const line of text.split("\n")) {
            const t = line.trim();
            if (t === "")
                continue;
            try {
                const s = JSON.parse(t);
                if (s && typeof s.sessionId === "string" && /^[A-Za-z0-9._-]+$/.test(s.sessionId) && typeof s.pid === "number" && !s.isSubagent)
                    parsed.push(s);
            } catch (e) {
            }
        }
        const keys = {};
        const next = parsed.map(s => {
            let seen = false;
            if (s.state === "done") {
                const key = seenKey(s);
                seen = seenKeys[key] ?? (!primed || lookingAt(s));
                keys[key] = seen;
            }
            return Object.assign({}, s, {
                seen
            });
        });
        seenKeys = keys;
        primed = true;
        sessions = next.sort((a, b) => rank(a) - rank(b) || a.startedAt - b.startedAt);
        checkLiveness();
    }

    function rank(s) {
        switch (s.state) {
        case "waiting":
            return 0;
        case "error":
            return 1;
        case "working":
            return 2;
        case "done":
            return s.seen ? 4 : 3;
        default:
            return 5;
        }
    }

    // Focusing a session's terminal marks its finished state as seen.
    function markSeen() {
        if (!ternFocused)
            return;
        const keys = Object.assign({}, seenKeys);
        let changed = false;
        for (const s of sessions) {
            if (s.state === "done" && !s.seen && lookingAt(s)) {
                keys[seenKey(s)] = true;
                changed = true;
            }
        }
        if (!changed)
            return;
        seenKeys = keys;
        sessions = sessions.map(s => s.state === "done" && !s.seen && keys[seenKey(s)] ? Object.assign({}, s, {
                seen: true
            }) : s).sort((a, b) => rank(a) - rank(b) || a.startedAt - b.startedAt);
    }

    onTernFocusedChanged: markSeen()

    // --- Liveness ------------------------------------------------------------
    function checkLiveness() {
        if (liveness.running || sessions.length === 0)
            return;
        liveness.command = ["sh", "-c", 'for p in "$@"; do [ -d "/proc/$p" ] || printf "%s\\n" "$p"; done', "sh"].concat(sessions.map(s => String(s.pid)));
        liveness.running = true;
    }

    function prune(text) {
        const dead = text.split("\n").map(l => parseInt(l.trim())).filter(n => !isNaN(n));
        if (dead.length === 0)
            return;
        const stale = sessions.filter(s => dead.indexOf(s.pid) >= 0);
        if (stale.length === 0)
            return;
        sessions = sessions.filter(s => dead.indexOf(s.pid) < 0);
        Quickshell.execDetached(["rm", "-f"].concat(stale.map(s => `${dir}/${s.sessionId}.json`)));
    }

    Process {
        id: scanner

        command: ["sh", "-c", 'cat -- "$1"/*.json 2>/dev/null; exit 0', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
        onRunningChanged: {
            if (!running && root.rescan) {
                root.rescan = false;
                root.scan();
            }
        }
    }

    Process {
        id: liveness

        stdout: StdioCollector {
            onStreamFinished: root.prune(text)
        }
    }

    // The extension creates the directory too; creating it here lets the
    // watch start before the first session.
    Process {
        id: mkdir

        running: root.available
        command: ["mkdir", "-p", root.dir]
        onExited: {
            watcher.running = true;
            root.scan();
        }
    }

    Process {
        id: watcher

        command: ["inotifywait", "-m", "-q", "-e", "close_write,moved_to,delete,moved_from", "--format", "%f", root.dir]
        stdout: SplitParser {
            onRead: line => {
                if (line.endsWith(".json"))
                    debounce.restart();
            }
        }
        // inotifywait missing or gone: fall back to polling.
        onRunningChanged: {
            if (!running && root.available)
                poll.running = true;
        }
    }

    // A state change is one rename; a burst of sessions settles within this.
    Timer {
        id: debounce

        interval: 60
        onTriggered: root.scan()
    }

    Timer {
        id: poll

        interval: 2000
        repeat: true
        onTriggered: root.scan()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.sessions.length > 0
        onTriggered: root.checkLiveness()
    }
}
