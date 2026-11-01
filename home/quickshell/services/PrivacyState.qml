pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What is watching or listening right now.
//
// screen: niri screencasts (PipeWire casts name their consumer through the
//         pipewire link, wlr-screencopy casts through /proc/<pid>/cmdline).
// mic/camera: pipewire links that flow from a real device source (not a
//         sink monitor, so visualizers do not count) into an active stream.
// remote: inbound ssh (local :22) and RustDesk (direct :21118, relay
//         peer :21117) connections from /proc/net/tcp{,6}, read every 5 s.
// Items keep their first-seen time and linger a few seconds after they stop.
Singleton {
    id: root

    readonly property int linger: 3000
    readonly property var order: ["screen", "mic", "camera", "remote"]

    // [{ id, category, app, what, since, ended, sessionId, muted }]
    property var items: []
    readonly property var categories: order.filter(c => items.some(i => i.category === c))
    readonly property bool any: items.length > 0

    function stopCast(item) {
        if (item.sessionId !== null)
            Niri.stopCast(item.sessionId);
    }

    // --- Pipewire graph ---------------------------------------------------
    readonly property var links: Pipewire.linkGroups.values
    readonly property var castIds: Niri.casts.map(c => c.pw_node_id).filter(id => id !== null && id !== undefined)
    readonly property var castLinks: links.filter(l => l.source !== null && castIds.includes(l.source.id))
    readonly property var deviceLinks: links.filter(l => isDeviceSource(l.source) && l.target !== null && !ownNode(l.target))

    function isDeviceSource(n) {
        return n !== null && !n.isStream && (n.type & PwNodeType.Source) !== 0;
    }

    function ownNode(n) {
        const props = n.properties ?? {};
        const pid = parseInt(props["application.process.id"] ?? "0");
        return pid === Quickshell.processId || /quickshell/i.test(props["application.name"] ?? "");
    }

    function nodeApp(n) {
        if (n === null)
            return "";
        const props = n.properties ?? {};
        return props["application.name"] || props["node.name"] || n.description || n.name;
    }

    // Bind every link and every node that takes part in one: unbound objects
    // report no link state, node type or properties, so filtering before
    // binding would never match.
    PwObjectTracker {
        objects: root.links.concat(root.links.map(l => l.source), root.links.map(l => l.target)).filter(o => o !== null)
    }

    // --- Screen -----------------------------------------------------------
    readonly property var screenItems: Niri.casts.filter(c => c.is_active).map(c => {
        const target = c.target ?? {};
        const what = target.Output ? `output ${target.Output.name}` : target.Window ? (Niri.windows[target.Window.id]?.title || "a window") : "no target yet";
        let app = "";
        if (c.pw_node_id !== null && c.pw_node_id !== undefined) {
            const link = castLinks.find(l => l.source.id === c.pw_node_id);
            if (link)
                app = nodeApp(link.target);
        }
        if (app === "" && c.pid)
            app = commands[c.pid] ?? "";
        if (app === "")
            app = c.kind === "WlrScreencopy" ? "screencopy client" : "screencast";
        return {
            id: `screen:${c.stream_id}`,
            category: "screen",
            app,
            what,
            sessionId: c.kind === "PipeWire" ? c.session_id : null
        };
    })

    // pid -> program name, for wlr-screencopy casts.
    property var commands: ({})
    readonly property var castPids: Array.from(new Set(Niri.casts.map(c => c.pid).filter(p => p)))

    Instantiator {
        model: root.castPids

        delegate: FileView {
            required property int modelData

            path: `/proc/${modelData}/cmdline`
            onLoaded: {
                const argv0 = text().split("\0")[0] ?? "";
                const base = argv0.split("/").pop().replace(/^\./, "").replace(/-wrapped$/, "");
                const next = Object.assign({}, root.commands);
                next[modelData] = base.startsWith("xdg-desktop-portal") ? "portal screencast" : base;
                root.commands = next;
            }
        }
    }

    // --- Microphone and camera -------------------------------------------
    readonly property var micItems: deviceLinks.filter(l => (l.source.type & PwNodeType.Audio) !== 0 && l.state === PwLinkState.Active).map(l => ({
                id: `mic:${l.source.id}:${l.target.id}`,
                category: "mic",
                app: nodeApp(l.target),
                what: l.source.nickname || l.source.description || l.source.name,
                sessionId: null,
                muted: l.source.audio?.muted ?? false
            }))

    readonly property var cameraItems: deviceLinks.filter(l => (l.source.type & PwNodeType.Video) !== 0 && l.state === PwLinkState.Active).map(l => ({
                id: `camera:${l.source.id}:${l.target.id}`,
                category: "camera",
                app: nodeApp(l.target),
                what: l.source.nickname || l.source.description || l.source.name,
                sessionId: null
            }))

    // --- Remote sessions --------------------------------------------------
    readonly property var remoteItems: {
        const peers = {};
        for (const c of parseTcp(tcp4.text(), false).concat(parseTcp(tcp6.text(), true))) {
            let app = "";
            if (c.localPort === 22)
                app = "SSH";
            else if (c.localPort === 21118)
                app = "RustDesk";
            else if (c.remotePort === 21117)
                app = "RustDesk relay";
            else
                continue;
            const key = `${app}:${c.peer}`;
            peers[key] = (peers[key] ?? 0) + 1;
        }
        return Object.keys(peers).sort().map(key => {
            const [app, peer] = [key.slice(0, key.indexOf(":")), key.slice(key.indexOf(":") + 1)];
            const n = peers[key];
            return {
                id: `remote:${key}`,
                category: "remote",
                app,
                what: n > 1 ? `from ${peer} (${n} sessions)` : `from ${peer}`,
                sessionId: null
            };
        });
    }

    function parseTcp(text, v6) {
        const out = [];
        for (const line of text.split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length < 4 || f[3] !== "01")
                continue;
            const [local, localPort] = f[1].split(":");
            const [remote, remotePort] = f[2].split(":");
            out.push({
                localPort: parseInt(localPort, 16),
                remotePort: parseInt(remotePort, 16),
                peer: v6 ? hexAddr6(remote) : hexAddr4(remote)
            });
        }
        return out;
    }

    // /proc/net/tcp prints each 32-bit word little-endian.
    function hexAddr4(hex) {
        const b = [];
        for (let i = 6; i >= 0; i -= 2)
            b.push(parseInt(hex.slice(i, i + 2), 16));
        return b.join(".");
    }

    function hexAddr6(hex) {
        let bytes = "";
        for (let w = 0; w < 32; w += 8)
            for (let i = w + 6; i >= w; i -= 2)
                bytes += hex.slice(i, i + 2);
        if (/^0{20}ffff/i.test(bytes))
            return hexAddr4(bytes.slice(24, 32).match(/../g).reverse().join(""));
        return bytes.match(/.{4}/g).map(g => g.replace(/^0+(?=.)/, "").toLowerCase()).join(":");
    }

    FileView {
        id: tcp4

        path: "/proc/net/tcp"
    }

    FileView {
        id: tcp6

        path: "/proc/net/tcp6"
    }

    Timer {
        running: true
        interval: 5000
        repeat: true
        onTriggered: {
            tcp4.reload();
            tcp6.reload();
        }
    }

    // --- Merge with linger ------------------------------------------------
    readonly property var live: screenItems.concat(micItems, cameraItems, remoteItems)
    onLiveChanged: merge()

    function merge() {
        const now = Date.now();
        const next = [];
        const seen = {};
        for (const it of live) {
            const old = items.find(o => o.id === it.id);
            next.push(Object.assign({}, it, {
                since: old?.since ?? now,
                ended: 0
            }));
            seen[it.id] = true;
        }
        let soonest = Infinity;
        for (const old of items) {
            if (seen[old.id])
                continue;
            const ended = old.ended || now;
            if (now - ended >= linger)
                continue;
            next.push(Object.assign({}, old, {
                ended
            }));
            soonest = Math.min(soonest, ended + linger - now);
        }
        items = next;
        if (soonest < Infinity) {
            prune.interval = Math.max(50, soonest + 20);
            prune.restart();
        }
    }

    Timer {
        id: prune

        onTriggered: root.merge()
    }
}
