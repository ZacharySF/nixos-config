pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live mirror of niri's state from its IPC event stream, plus actions.
//
// The event stream sends the complete state up front and then deltas, so the
// mirror cannot desync (niri wiki: IPC). Objects are replaced, never mutated
// in place, so QML bindings on `windows`/`workspaces` re-evaluate.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool available: socketPath !== ""

    property var workspaces: []
    property var windows: ({})
    property var focusedWindowId: null
    property bool overviewOpen: false
    property var casts: []
    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0

    readonly property var windowList: Object.values(windows)
    readonly property var focusedWindow: focusedWindowId !== null ? (windows[focusedWindowId] ?? null) : null
    readonly property var stashWorkspace: workspaces.find(w => w.name === "stash") ?? null
    readonly property var stashWindows: stashWorkspace ? windowList.filter(w => w.workspace_id === stashWorkspace.id) : []
    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null

    // Workspaces of one output in display order. The scratchpad stash is left
    // out unless you are on it, so its windows show in the minimap then.
    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output && (w.name !== "stash" || w.is_active)).sort((a, b) => a.idx - b.idx);
    }

    function workspace(id) {
        return workspaces.find(w => w.id === id) ?? null;
    }

    function windowsOn(workspaceId) {
        return windowList.filter(w => w.workspace_id === workspaceId);
    }

    // Tiled columns of a workspace, left to right:
    // [{ index, width, tiles: [window, ...] (top to bottom) }]
    function columnsOn(workspaceId) {
        const byColumn = {};
        for (const w of windowList) {
            if (w.workspace_id !== workspaceId || w.is_floating)
                continue;
            const pos = w.layout?.pos_in_scrolling_layout;
            if (!pos)
                continue;
            if (!byColumn[pos[0]])
                byColumn[pos[0]] = [];
            byColumn[pos[0]].push(w);
        }
        return Object.keys(byColumn).map(Number).sort((a, b) => a - b).map(index => {
            const tiles = byColumn[index].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]);
            return {
                index,
                width: Math.max(...tiles.map(t => t.layout.tile_size[0])),
                tiles
            };
        });
    }

    function floatingOn(workspaceId) {
        return windowList.filter(w => w.workspace_id === workspaceId && w.is_floating);
    }

    // --- Actions ----------------------------------------------------------
    // Each request opens a short-lived socket: niri answers one JSON line
    // per request and closes nothing on its side, so we disconnect after it.
    function request(payload, callback) {
        if (!available)
            return;
        const s = requestSocket.createObject(root, {
            payload: JSON.stringify(payload),
            callback: callback ?? null
        });
        s.connected = true;
    }

    function action(name, args) {
        request({
            Action: {
                [name]: args ?? {}
            }
        });
    }

    function focusWindow(id) {
        action("FocusWindow", {
            id
        });
    }
    function closeWindow(id) {
        action("CloseWindow", {
            id
        });
    }
    function focusWorkspace(id) {
        action("FocusWorkspace", {
            reference: {
                Id: id
            }
        });
    }
    function toggleOverview() {
        action("ToggleOverview");
    }
    function focusColumnLeft() {
        action("FocusColumnLeft");
    }
    function focusColumnRight() {
        action("FocusColumnRight");
    }
    function stopCast(sessionId) {
        action("StopCast", {
            session_id: sessionId
        });
    }
    // Bring a window to the focused workspace and focus it.
    function summonWindow(id) {
        const target = focusedWorkspace;
        if (!target)
            return;
        action("MoveWindowToWorkspace", {
            window_id: id,
            reference: {
                Id: target.id
            },
            focus: true
        });
        focusWindow(id);
    }

    Component {
        id: requestSocket

        Socket {
            id: sock

            property string payload
            property var callback

            path: root.socketPath
            onConnectedChanged: {
                if (connected) {
                    write(payload + "\n");
                    flush();
                }
            }
            onError: sock.destroy()

            parser: SplitParser {
                onRead: line => {
                    if (sock.callback) {
                        try {
                            sock.callback(JSON.parse(line));
                        } catch (e) {
                            console.warn("niri reply:", e);
                        }
                    }
                    sock.connected = false;
                    sock.destroy();
                }
            }
        }
    }

    // --- Event stream -----------------------------------------------------
    Socket {
        id: events

        path: root.socketPath
        connected: root.available
        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else {
                reconnect.restart();
            }
        }

        parser: SplitParser {
            onRead: line => root.handle(line)
        }
    }

    // niri restarts or reloads drop the stream; reconnect until it is back.
    Timer {
        id: reconnect

        interval: 1000
        onTriggered: {
            if (!events.connected)
                events.connected = true;
            if (!events.connected)
                restart();
        }
    }

    function handle(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.Ok !== undefined || ev.Err !== undefined)
            return;

        const [kind, body] = Object.entries(ev)[0];
        switch (kind) {
        case "WorkspacesChanged":
            workspaces = body.workspaces;
            break;
        case "WorkspaceActivated":
            {
                const target = workspaces.find(w => w.id === body.id);
                workspaces = workspaces.map(w => {
                    const n = Object.assign({}, w);
                    if (target && w.output === target.output)
                        n.is_active = w.id === body.id;
                    if (body.focused)
                        n.is_focused = w.id === body.id;
                    return n;
                });
                break;
            }
        case "WorkspaceActiveWindowChanged":
            workspaces = workspaces.map(w => w.id === body.workspace_id ? Object.assign({}, w, {
                    active_window_id: body.active_window_id
                }) : w);
            break;
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(w => w.id === body.id ? Object.assign({}, w, {
                    is_urgent: body.urgent
                }) : w);
            break;
        case "WindowsChanged":
            {
                const map = {};
                let focused = null;
                for (const w of body.windows) {
                    map[w.id] = w;
                    if (w.is_focused)
                        focused = w.id;
                }
                windows = map;
                focusedWindowId = focused;
                break;
            }
        case "WindowOpenedOrChanged":
            {
                const w = body.window;
                const map = Object.assign({}, windows);
                if (w.is_focused) {
                    for (const id in map)
                        if (map[id].is_focused)
                            map[id] = Object.assign({}, map[id], {
                                is_focused: false
                            });
                    focusedWindowId = w.id;
                }
                map[w.id] = w;
                windows = map;
                break;
            }
        case "WindowClosed":
            {
                const map = Object.assign({}, windows);
                delete map[body.id];
                windows = map;
                if (focusedWindowId === body.id)
                    focusedWindowId = null;
                break;
            }
        case "WindowFocusChanged":
            {
                const map = {};
                for (const id in windows) {
                    const w = windows[id];
                    const focused = w.id === body.id;
                    map[id] = w.is_focused === focused ? w : Object.assign({}, w, {
                        is_focused: focused
                    });
                }
                windows = map;
                focusedWindowId = body.id;
                break;
            }
        case "WindowUrgencyChanged":
            if (windows[body.id]) {
                const map = Object.assign({}, windows);
                map[body.id] = Object.assign({}, map[body.id], {
                    is_urgent: body.urgent
                });
                windows = map;
            }
            break;
        case "WindowLayoutsChanged":
            {
                const map = Object.assign({}, windows);
                for (const [id, layout] of body.changes)
                    if (map[id])
                        map[id] = Object.assign({}, map[id], {
                            layout
                        });
                windows = map;
                break;
            }
        case "KeyboardLayoutsChanged":
            keyboardLayouts = body.keyboard_layouts.names;
            keyboardLayoutIndex = body.keyboard_layouts.current_idx;
            break;
        case "KeyboardLayoutSwitched":
            keyboardLayoutIndex = body.idx;
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = body.is_open;
            break;
        case "CastsChanged":
            casts = body.casts;
            break;
        case "CastStartedOrChanged":
            casts = casts.filter(c => c.stream_id !== body.cast.stream_id).concat([body.cast]);
            break;
        case "CastStopped":
            casts = casts.filter(c => c.stream_id !== body.stream_id);
            break;
        }
    }
}
