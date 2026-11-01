pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NixOS system state for the NixStatus item: local builds in progress, a
// built-but-not-activated generation, a kernel change waiting for a reboot,
// flake input ages and running Podman containers.
//
// Event sources: /nix/var/nix/temproots gains and loses a file per nix
// process, /nix/var/nix/profiles changes when a generation is added or the
// `system` link moves. Both directories are watched; `ps` runs only after a
// temproots event and then every 3 s while nixbld users own processes, and
// the generation probe runs after a profile event (plus every 30 s while a
// switch is pending, since activation does not touch the profile).
Singleton {
    id: root

    readonly property string flakeDir: Quickshell.env("HOME") + "/nixos"
    readonly property int staleDays: 14

    // Set by the popover; refreshes containers and the generation probe.
    property bool watching: false

    // --- Builds ------------------------------------------------------------
    // Number of nixbld users that own a process = derivations building locally.
    property int building: 0

    // --- Generations -------------------------------------------------------
    property int currentGeneration: 0
    property date currentDate: new Date(0)
    property string currentVersion: ""
    property int profileGeneration: 0
    property date profileDate: new Date(0)
    property string profilePath: ""
    property string currentPath: ""
    property string bootedPath: ""
    property string bootedKernel: ""
    property string currentKernel: ""
    property bool kernelChanged: false

    readonly property bool switchPending: profilePath !== "" && currentPath !== "" && profilePath !== currentPath
    readonly property bool rebootPending: kernelChanged

    // --- Flake inputs ------------------------------------------------------
    // [{ name, days, stale }] for every root input, oldest first.
    property var inputs: []

    // --- Podman ------------------------------------------------------------
    property int containers: 0

    readonly property bool shown: building > 0 || switchPending || rebootPending

    // "/nix/store/<hash>-linux-xanmod-7.2.11/bzImage" -> "linux-xanmod-7.2.11"
    function storeName(path) {
        const dir = path.split("/")[3] ?? "";
        return dir.length > 33 ? dir.slice(33) : dir;
    }

    onWatchingChanged: {
        if (watching) {
            probe.running = true;
            podman.running = true;
        }
    }

    // --- Build detection ---------------------------------------------------
    FileView {
        path: "/nix/var/nix/temproots"
        watchChanges: true
        preload: false
        onFileChanged: psDebounce.restart()
    }

    Timer {
        id: psDebounce

        interval: 500
        onTriggered: ps.running = true
    }

    Process {
        id: ps

        running: true
        command: ["ps", "-eo", "user="]
        stdout: StdioCollector {
            onStreamFinished: {
                const users = new Set();
                for (const line of text.split("\n")) {
                    const u = line.trim();
                    if (u.startsWith("nixbld"))
                        users.add(u);
                }
                root.building = users.size;
            }
        }
    }

    Timer {
        interval: 3000
        running: root.building > 0
        repeat: true
        onTriggered: ps.running = true
    }

    // --- Generation probe --------------------------------------------------
    FileView {
        path: "/nix/var/nix/profiles"
        watchChanges: true
        preload: false
        onFileChanged: probeDebounce.restart()
    }

    Timer {
        id: probeDebounce

        interval: 2000
        onTriggered: probe.running = true
    }

    Timer {
        interval: 30000
        running: root.switchPending
        repeat: true
        onTriggered: probe.running = true
    }

    // A finished local build often precedes an activation.
    onBuildingChanged: if (building === 0) probeDebounce.restart()

    Process {
        id: probe

        running: true
        command: ["sh", "-c", `
p=/nix/var/nix/profiles
cur=$(readlink -f /run/current-system)
echo "current $cur"
echo "booted $(readlink -f /run/booted-system)"
echo "profile $(readlink -f $p/system)"
echo "profile-gen $(readlink $p/system) $(stat -c %Y $p/$(readlink $p/system))"
for l in $p/system-*-link; do
  [ "$(readlink -f "$l")" = "$cur" ] && echo "current-gen $(basename "$l") $(stat -c %Y "$l")"
done
echo "version $(cat /run/current-system/nixos-version 2>/dev/null)"
for f in kernel initrd kernel-modules; do
  echo "current-$f $(readlink -f /run/current-system/$f)"
  echo "booted-$f $(readlink -f /run/booted-system/$f)"
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(" ");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1);
                }
                const gen = s => {
                    const m = (s ?? "").match(/^system-(\d+)-link (\d+)$/);
                    return m ? {
                        n: Number(m[1]),
                        date: new Date(Number(m[2]) * 1000)
                    } : null;
                };
                const cur = gen(v["current-gen"]);
                const prof = gen(v["profile-gen"]);
                root.currentPath = v.current ?? "";
                root.bootedPath = v.booted ?? "";
                root.profilePath = v.profile ?? "";
                root.currentVersion = v.version ?? "";
                root.currentGeneration = cur?.n ?? 0;
                root.currentDate = cur?.date ?? new Date(0);
                root.profileGeneration = prof?.n ?? 0;
                root.profileDate = prof?.date ?? new Date(0);
                root.currentKernel = v["current-kernel"] ?? "";
                root.bootedKernel = v["booted-kernel"] ?? "";
                root.kernelChanged = ["kernel", "initrd", "kernel-modules"].some(f => v["current-" + f] !== v["booted-" + f]);
            }
        }
    }

    // --- Flake inputs ------------------------------------------------------
    FileView {
        id: lockFile

        path: root.flakeDir + "/flake.lock"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let lock;
            try {
                lock = JSON.parse(text());
            } catch (e) {
                return;
            }
            const rootNode = lock.nodes?.[lock.root] ?? {};
            const now = Date.now() / 1000;
            const out = [];
            for (const [name, ref] of Object.entries(rootNode.inputs ?? {})) {
                const node = typeof ref === "string" ? lock.nodes[ref] : null;
                const modified = node?.locked?.lastModified;
                if (!modified)
                    continue;
                const days = Math.floor((now - modified) / 86400);
                out.push({
                    name,
                    days,
                    stale: days > root.staleDays
                });
            }
            root.inputs = out.sort((a, b) => b.days - a.days || a.name.localeCompare(b.name));
        }
    }

    // --- Podman ------------------------------------------------------------
    Process {
        id: podman

        command: ["podman", "ps", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.containers = JSON.parse(text).length;
                } catch (e) {
                    root.containers = 0;
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: root.watching
        repeat: true
        onTriggered: podman.running = true
    }
}
