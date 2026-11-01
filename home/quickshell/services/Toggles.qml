pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Session toggles kept by the shell scripts in hosts/o8/scripts.nix:
//   tablet mode + mode lock  $XDG_RUNTIME_DIR/tablet-mode/{mode,lock}  (tablet-mode)
//   rotation lock            /tmp/rotation/lock                         (rotation-lock)
//   caffeine                 /tmp/caffeine/state  blue = lid, green = lid + idle
// One inotifywait watches all three directories, so changes made from the
// keyboard or a terminal show up immediately and nothing polls.
Singleton {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? "/run/user/1000"
    readonly property string modeDir: runtimeDir + "/tablet-mode"

    property bool tabletMode: false
    property string modeLock: "auto" // auto | laptop | tablet
    property bool rotationLocked: false
    property string caffeine: "off" // off | lid | full
    property bool oskRunning: false

    function setMode(lock) {
        Quickshell.execDetached(["tablet-mode", "set", lock]);
    }
    function toggleRotationLock() {
        Quickshell.execDetached(["rotation-lock", "toggle"]);
    }
    function toggleOsk() {
        oskProc.command = ["osk-toggle"];
        oskProc.running = true;
    }
    // Cycles off -> lid -> full -> off, as the script defines.
    function cycleCaffeine() {
        Quickshell.execDetached(["caffeine-toggle"]);
    }
    function caffeineOff() {
        // caffeine-toggle only cycles; from lid it takes two steps to off.
        if (caffeine === "lid")
            Quickshell.execDetached(["sh", "-c", "caffeine-toggle && caffeine-toggle"]);
        else if (caffeine === "full")
            Quickshell.execDetached(["caffeine-toggle"]);
    }

    function refresh() {
        modeFile.reload();
        lockFile.reload();
        rotFile.reload();
        cafFile.reload();
        oskCheck.running = true;
    }

    FileView {
        id: modeFile

        path: root.modeDir + "/mode"
        onLoaded: root.tabletMode = text().trim() === "tablet"
        // No mode file yet (no hinge event since login): ask systemd once.
        onLoadFailed: targetCheck.running = true
    }
    FileView {
        id: lockFile

        path: root.modeDir + "/lock"
        onLoaded: root.modeLock = text().trim() || "auto"
        onLoadFailed: root.modeLock = "auto"
    }
    FileView {
        id: rotFile

        path: "/tmp/rotation/lock"
        onLoaded: root.rotationLocked = true
        onLoadFailed: root.rotationLocked = false
    }
    FileView {
        id: cafFile

        path: "/tmp/caffeine/state"
        onLoaded: {
            const s = text().trim();
            root.caffeine = s === "blue" ? "lid" : s === "green" ? "full" : "off";
        }
        onLoadFailed: root.caffeine = "off"
    }

    Process {
        id: targetCheck

        command: ["systemctl", "--user", "is-active", "--quiet", "tablet-mode.target"]
        onExited: code => root.tabletMode = code === 0
    }
    Process {
        id: oskCheck

        command: ["systemctl", "--user", "is-active", "--quiet", "wvkbd.service"]
        onExited: code => root.oskRunning = code === 0
    }
    Process {
        id: oskProc

        onExited: oskCheck.running = true
    }

    // Directories may not exist before the first toggle; create them so the
    // watch can start. Fixed paths only.
    Process {
        id: watcher

        running: true
        command: ["sh", "-c", 'mkdir -p "$1" /tmp/rotation /tmp/caffeine && exec inotifywait -mq -e create,delete,modify,moved_to,moved_from --format "%w%f" "$1" /tmp/rotation /tmp/caffeine', "sh", root.modeDir]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        onExited: restartWatch.start()
    }
    Timer {
        id: restartWatch

        interval: 2000
        onTriggered: watcher.running = true
    }
    Timer {
        id: debounce

        interval: 80
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
