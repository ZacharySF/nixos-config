pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (org.freedesktop.Notifications) with history.
//
// Each entry wraps a live Notification while the sender still tracks it and
// keeps a snapshot afterwards, so the center can show history across
// restarts (state file below). Popups are suppressed, not lost, while
// Do Not Disturb is on, while a screen is being shared, or while the focused
// window is fullscreen; critical notifications always pop up. Notifications
// from the app you are looking at are marked read and do not pop up.
Singleton {
    id: root

    // Newest first: { key, notif, appName, appIcon, desktopEntry, summary,
    // body, image, urgency (0 low, 1 normal, 2 critical), time, actions,
    // read, live }
    property var entries: []
    // Keys of entries currently shown as popups, oldest first (max four).
    property var popups: []
    property bool dnd: false
    // The center (bell popover) is open somewhere; popups hide meanwhile.
    property bool centerOpen: false
    property var mutedApps: []
    property int nextKey: 1

    readonly property int maxHistory: 150
    readonly property bool sharingScreen: Niri.casts.some(c => c.is_active)
    readonly property bool fullscreen: {
        const w = Niri.focusedWindow;
        if (!w || !w.layout)
            return false;
        const ws = Niri.workspace(w.workspace_id);
        const screen = Quickshell.screens.find(s => s.name === ws?.output);
        return !!screen && w.layout.window_size[0] >= screen.width && w.layout.window_size[1] >= screen.height;
    }
    readonly property string pauseReason: dnd ? "Do not disturb" : sharingScreen ? "Paused while sharing your screen" : fullscreen ? "Paused while fullscreen" : ""
    readonly property int unread: entries.filter(e => !e.read && e.urgency >= 1 && !isMuted(e.appName)).length
    readonly property var popupEntries: popups.map(k => entries.find(e => e.key === k)).filter(e => !!e)

    signal centerRequested

    function isMuted(app) {
        return mutedApps.indexOf(app) >= 0;
    }

    function appKey(e) {
        return (e.desktopEntry || e.appName || "").toLowerCase();
    }

    function focusedAppMatches(e) {
        const w = Niri.focusedWindow;
        if (!w)
            return false;
        const id = (w.app_id ?? "").toLowerCase();
        const key = appKey(e);
        return key !== "" && (id === key || id.endsWith("." + key) || key.endsWith("." + id));
    }

    function replace(key, patch) {
        entries = entries.map(e => e.key === key ? Object.assign({}, e, patch) : e);
    }

    function hidePopup(key) {
        popups = popups.filter(k => k !== key);
    }

    function markAllRead() {
        if (entries.some(e => !e.read))
            entries = entries.map(e => e.read ? e : Object.assign({}, e, {
                    read: true
                }));
    }

    function dismiss(key) {
        const e = entries.find(x => x.key === key);
        hidePopup(key);
        entries = entries.filter(x => x.key !== key);
        if (e?.notif && e.live)
            e.notif.dismiss();
    }

    function clearAll() {
        const live = entries.filter(e => e.notif && e.live);
        popups = [];
        entries = [];
        for (const e of live)
            e.notif.dismiss();
    }

    function toggleMute(app) {
        mutedApps = isMuted(app) ? mutedApps.filter(a => a !== app) : mutedApps.concat([app]);
    }

    // Click on a notification: run its default action if it has one,
    // otherwise focus the sender's window. Either way it leaves the popups.
    function activate(key) {
        const e = entries.find(x => x.key === key);
        if (!e)
            return;
        hidePopup(key);
        replace(key, {
            read: true
        });
        const def = e.live ? e.notif.actions.find(a => a.identifier === "default") : null;
        if (def) {
            def.invoke();
            return;
        }
        const keyName = appKey(e);
        const win = Niri.windowList.find(w => {
            const id = (w.app_id ?? "").toLowerCase();
            return keyName !== "" && (id === keyName || id.endsWith("." + keyName) || keyName.endsWith("." + id));
        });
        if (win)
            Niri.focusWindow(win.id);
    }

    function invokeAction(key, identifier) {
        const e = entries.find(x => x.key === key);
        if (!e || !e.live)
            return;
        const a = e.notif.actions.find(x => x.identifier === identifier);
        if (a)
            a.invoke();
        hidePopup(key);
        replace(key, {
            read: true
        });
    }

    function reply(key, text) {
        const e = entries.find(x => x.key === key);
        if (e?.live && e.notif.hasInlineReply)
            e.notif.sendInlineReply(text);
        hidePopup(key);
    }

    function accept(n) {
        n.tracked = true;
        const urgency = n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1;

        // A config reload re-emits notifications the previous generation
        // tracked. Reattach them to their restored history entry instead of
        // showing them again.
        if (n.lastGeneration) {
            const old = entries.find(e => e.nid === n.id && !e.live);
            if (old) {
                replace(old.key, {
                    notif: n,
                    live: true
                });
                watch(n, old.key, old.transient);
                return;
            }
        }

        const entry = {
            key: nextKey++,
            nid: n.id,
            notif: n,
            live: true,
            appName: n.appName,
            appIcon: n.appIcon,
            desktopEntry: n.desktopEntry,
            summary: n.summary,
            body: n.body,
            image: n.image,
            urgency,
            time: Date.now(),
            actions: n.actions.map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    })),
            read: n.lastGeneration,
            revived: n.lastGeneration,
            transient: n.transient
        };
        const lookingAtIt = urgency < 2 && focusedAppMatches(entry);
        const muted = urgency < 2 && isMuted(entry.appName);
        if (lookingAtIt)
            entry.read = true;
        entries = [entry].concat(entries).slice(0, maxHistory);

        const quiet = pauseReason !== "" && urgency < 2;
        if (!n.lastGeneration && !lookingAtIt && !muted && !quiet)
            popups = popups.concat([entry.key]).slice(-4);
        watch(n, entry.key, entry.transient);
    }

    // Keep the snapshot current while the sender updates it in place, and
    // turn it into history when the sender closes it.
    function watch(n, key, transient) {
        const sync = () => replace(key, {
                summary: n.summary,
                body: n.body,
                image: n.image,
                appIcon: n.appIcon,
                actions: n.actions.map(a => ({
                            identifier: a.identifier,
                            text: a.text
                        }))
            });
        n.summaryChanged.connect(sync);
        n.bodyChanged.connect(sync);
        n.imageChanged.connect(sync);
        n.actionsChanged.connect(sync);
        n.closed.connect(() => {
            hidePopup(key);
            if (transient)
                entries = entries.filter(x => x.key !== key);
            else
                replace(key, {
                    live: false,
                    notif: null
                });
        });
    }

    LazyLoader {
        active: Config.notifications

        NotificationServer {
            keepOnReload: true
            persistenceSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            actionsSupported: true
            actionIconsSupported: true
            imageSupported: true
            inlineReplySupported: true
            onNotification: n => root.accept(n)
        }
    }

    // --- Persistence -------------------------------------------------------
    FileView {
        id: store

        path: Quickshell.statePath("notifications.json")
        atomicWrites: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.dnd = !!data.dnd;
                root.mutedApps = data.mutedApps ?? [];
                // Entries re-emitted by a reload before this file loaded keep
                // their live notification but take back their original time.
                let current = root.entries;
                const restored = [];
                for (const e of data.entries ?? []) {
                    const twin = current.find(x => x.revived && x.nid === e.nid && x.summary === e.summary);
                    if (twin)
                        current = current.map(x => x === twin ? Object.assign({}, x, {
                                time: e.time,
                                read: e.read,
                                revived: false
                            }) : x);
                    else
                        restored.push(Object.assign({}, e, {
                            key: root.nextKey++,
                            notif: null,
                            live: false
                        }));
                }
                root.entries = current.concat(restored).sort((a, b) => b.time - a.time).slice(0, root.maxHistory);
            } catch (e) {
                console.warn("notifications: unreadable history", e);
            }
            saver.armed = true;
        }
        onLoadFailed: saver.armed = true
    }

    Timer {
        id: saver

        property bool armed: false

        interval: 800
        onTriggered: store.setText(JSON.stringify({
            dnd: root.dnd,
            mutedApps: root.mutedApps,
            entries: root.entries.filter(e => !e.transient).map(e => ({
                        nid: e.nid,
                        appName: e.appName,
                        appIcon: e.appIcon && !e.appIcon.startsWith("image://") ? e.appIcon : "",
                        desktopEntry: e.desktopEntry,
                        summary: e.summary,
                        body: e.body,
                        urgency: e.urgency,
                        time: e.time,
                        read: e.read
                    }))
        }))
    }

    onEntriesChanged: if (saver.armed) saver.restart()
    onDndChanged: if (saver.armed) saver.restart()
    onMutedAppsChanged: if (saver.armed) saver.restart()

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function toggleCenter(): void {
            root.centerRequested();
        }
        function clear(): void {
            root.clearAll();
        }
    }
}
