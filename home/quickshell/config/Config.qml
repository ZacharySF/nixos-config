pragma Singleton

import QtQuick
import Quickshell

// Runtime switches.
//
// BAR_DEV=1 runs a development copy next to the live bar: it docks at the
// bottom edge (raised by BAR_DEV_OFFSET pixels, so several copies can be
// compared), uses its own layer namespace, reserves no space and does not
// claim the notification bus name. BAR_NOTIFICATIONS=0/1 overrides whether
// this instance owns org.freedesktop.Notifications.
Singleton {
    readonly property bool dev: Quickshell.env("BAR_DEV") === "1"
    readonly property int devOffset: parseInt(Quickshell.env("BAR_DEV_OFFSET") ?? "0") || 0
    readonly property bool notifications: {
        const v = Quickshell.env("BAR_NOTIFICATIONS");
        return v === null || v === "" ? !dev : v === "1";
    }
    // Development only: lay the dev bar out as if the screen were this wide
    // (e.g. 900 for portrait) and/or in tablet mode, without rotating it.
    readonly property int devWidth: parseInt(Quickshell.env("BAR_DEV_WIDTH") ?? "0") || 0
    readonly property bool devTablet: Quickshell.env("BAR_DEV_TABLET") === "1"
    readonly property string namespace: dev ? "quickshell-bar-dev" : "quickshell-bar"
}
