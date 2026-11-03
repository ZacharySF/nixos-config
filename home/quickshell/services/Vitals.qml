pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Exception detector for the machine: samples /proc and sysfs every 3 s
// (plain file reads, no subprocess), keeps ~2 min of history per metric and
// lists the thresholds that are currently tripped. The bar item is hidden
// while `reasons` is empty.
//
// hwmon numbering is not stable across boots, so the sensors are resolved by
// chip name once at start. Disk usage comes from `df` once a minute, and the
// process list only while the popover is open.
Singleton {
    id: root

    // Set by the popover; refreshes the process list every sample.
    property bool watching: false

    // --- Thresholds --------------------------------------------------------
    readonly property real cpuHigh: 0.80 // sustained for cpuHoldMs
    readonly property int cpuHoldMs: 10000
    readonly property real memHigh: 0.85
    readonly property real memSevere: 0.95
    readonly property real swapHigh: 0.50
    readonly property real swapSevere: 0.90
    readonly property real zramHigh: 0.80
    readonly property int tempHigh: 85
    readonly property int tempSevere: 95
    readonly property int nvmeHigh: 70
    readonly property int nvmeSevere: 80
    // acpi_fan on this HP idles at 0 rpm, sits around 4300 rpm under a
    // normal desktop load and only passes 5500 rpm when the package is
    // pinned near its throttle point.
    readonly property int fanHigh: 5500
    readonly property int fanHoldMs: 30000
    readonly property int throttleHoldMs: 30000
    readonly property real diskLow: 0.10
    readonly property real diskSevere: 0.03
    readonly property int intervalMs: 3000
    readonly property int historyLength: 40

    // --- Current values ----------------------------------------------------
    property real cpu: 0 // 0..1
    property real mem: 0 // 0..1 of MemTotal in use (MemAvailable based)
    property real swap: 0 // 0..1 of all swap in use
    property real zram: 0 // 0..1 of the zram swap device in use, 0 without zram
    property int cpuTemp: 0 // degrees C, 0 when no sensor
    property int nvmeTemp: 0
    property int fan: 0 // rpm, -1 when no fan sensor
    property int throttleCount: 0
    property bool throttling: false
    // [{ mount, avail, size, free }] for / and /nix (merged when the same fs).
    property var disks: []
    // [{ pid, cpu, mem, name }], top 5 by CPU; filled while watching.
    property var processes: []

    // Newest last, one entry per sample.
    property var cpuHistory: []
    property var memHistory: []
    property var swapHistory: []
    property var tempHistory: []
    property var fanHistory: []

    // [{ key, text, severe }] of tripped thresholds.
    property var reasons: []
    readonly property bool tripped: reasons.length > 0
    readonly property bool severe: reasons.some(r => r.severe)

    readonly property bool hasCpuTemp: cpuTempFile.path !== ""
    readonly property bool hasNvmeTemp: nvmeTempFile.path !== ""
    readonly property bool hasFan: fanFile.path !== ""

    function openMissionCenter() {
        Quickshell.execDetached(["foot", "btop"]);
    }

    // --- Sensor discovery --------------------------------------------------
    Process {
        running: true
        command: ["sh", "-c", `
for h in /sys/class/hwmon/hwmon*; do
  n=$(cat "$h/name" 2>/dev/null) || continue
  case "$n" in
    coretemp)
      for f in "$h"/temp*_input; do
        case "$(cat "\${f%_input}_label" 2>/dev/null)" in Package*) echo "cpu $f";; esac
      done ;;
    acpitz) echo "acpitz $h/temp1_input" ;;
    nvme) echo "nvme $h/temp1_input" ;;
    acpi_fan) [ -f "$h/fan1_input" ] && echo "fan $h/fan1_input" ;;
  esac
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const [key, path] = line.split(" ");
                    if (key && path && !found[key])
                        found[key] = path;
                }
                cpuTempFile.path = found.cpu ?? found.acpitz ?? "";
                nvmeTempFile.path = found.nvme ?? "";
                fanFile.path = found.fan ?? "";
                if (fanFile.path === "")
                    root.fan = -1;
            }
        }
    }

    // --- Samples -----------------------------------------------------------
    property real prevTotal: 0
    property real prevIdle: 0
    property real cpuHighSince: 0
    property real fanHighSince: 0
    property real throttleSeenAt: 0

    FileView {
        id: statFile

        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.prevTotal > 0 && total > root.prevTotal)
                root.cpu = 1 - (idle - root.prevIdle) / (total - root.prevTotal);
            root.prevTotal = total;
            root.prevIdle = idle;
        }
    }

    FileView {
        id: meminfoFile

        path: "/proc/meminfo"
        onLoaded: {
            const v = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    v[m[1]] = Number(m[2]);
            }
            if (v.MemTotal > 0)
                root.mem = 1 - v.MemAvailable / v.MemTotal;
            root.swap = v.SwapTotal > 0 ? (v.SwapTotal - v.SwapFree) / v.SwapTotal : 0;
        }
    }

    FileView {
        id: swapsFile

        path: "/proc/swaps"
        onLoaded: {
            let used = 0, size = 0;
            for (const line of text().split("\n")) {
                const f = line.trim().split(/\s+/);
                if (f[0]?.startsWith("/dev/zram")) {
                    size += Number(f[2]);
                    used += Number(f[3]);
                }
            }
            root.zram = size > 0 ? used / size : 0;
        }
    }

    FileView {
        id: cpuTempFile

        onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
    }

    FileView {
        id: nvmeTempFile

        onLoaded: root.nvmeTemp = Math.round(Number(text()) / 1000)
    }

    FileView {
        id: fanFile

        onLoaded: root.fan = Number(text())
    }

    FileView {
        id: throttleFile

        path: "/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count"
        onLoaded: {
            const n = Number(text());
            if (root.throttleCount > 0 && n > root.throttleCount)
                root.throttleSeenAt = Date.now();
            root.throttleCount = n;
        }
    }

    Process {
        id: dfProc

        running: true
        command: ["df", "-B1", "--output=target,avail,size", "/", "/nix"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n").slice(1)) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 3 || out.some(d => d.mount === f[0]))
                        continue;
                    const avail = Number(f[1]), size = Number(f[2]);
                    out.push({
                        mount: f[0],
                        avail,
                        size,
                        free: size > 0 ? avail / size : 1
                    });
                }
                root.disks = out;
            }
        }
    }

    Process {
        id: psProc

        command: ["ps", "-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.processes = text.split("\n").slice(0, 5).map(line => {
                    const f = line.trim().split(/\s+/);
                    return {
                        pid: Number(f[0]),
                        cpu: Number(f[1]),
                        mem: Number(f[2]),
                        name: f.slice(3).join(" ")
                    };
                }).filter(p => p.pid > 0);
            }
        }
    }

    onWatchingChanged: if (watching) psProc.running = true

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        onTriggered: {
            root.evaluate();
            statFile.reload();
            meminfoFile.reload();
            swapsFile.reload();
            throttleFile.reload();
            if (cpuTempFile.path !== "")
                cpuTempFile.reload();
            if (nvmeTempFile.path !== "")
                nvmeTempFile.reload();
            if (fanFile.path !== "")
                fanFile.reload();
            if (root.watching)
                psProc.running = true;
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: dfProc.running = true
    }

    function push(list, value) {
        const out = list.length >= historyLength ? list.slice(list.length - historyLength + 1) : list.slice();
        out.push(value);
        return out;
    }

    // Hysteresis: a tripped metric stays tripped until it drops clearly
    // below its threshold, so the item does not flicker at the edge.
    function above(key, value, high, slack) {
        return value > (reasons.some(r => r.key === key) ? high - slack : high);
    }

    function evaluate() {
        const now = Date.now();
        const out = [];

        cpuHistory = push(cpuHistory, cpu);
        memHistory = push(memHistory, mem);
        swapHistory = push(swapHistory, swap);
        tempHistory = push(tempHistory, cpuTemp);
        fanHistory = push(fanHistory, Math.max(0, fan));

        if (above("cpu", cpu, cpuHigh, 0.1)) {
            if (cpuHighSince === 0)
                cpuHighSince = now;
            if (now - cpuHighSince >= cpuHoldMs)
                out.push({
                    key: "cpu",
                    text: `CPU ${Math.round(cpu * 100)}% for ${Math.round((now - cpuHighSince) / 1000)} s`,
                    severe: false
                });
        } else
            cpuHighSince = 0;

        if (above("mem", mem, memHigh, 0.03))
            out.push({
                key: "mem",
                text: `Memory ${Math.round(mem * 100)}% used`,
                severe: mem >= memSevere
            });

        if (above("swap", swap, swapHigh, 0.05))
            out.push({
                key: "swap",
                text: `Swap ${Math.round(swap * 100)}% used`,
                severe: swap >= swapSevere
            });
        else if (above("zram", zram, zramHigh, 0.05))
            out.push({
                key: "zram",
                text: `zram ${Math.round(zram * 100)}% full`,
                severe: false
            });

        if (hasCpuTemp && above("temp", cpuTemp, tempHigh, 3))
            out.push({
                key: "temp",
                text: `CPU ${cpuTemp} °C`,
                severe: cpuTemp >= tempSevere
            });

        if (hasNvmeTemp && above("nvme", nvmeTemp, nvmeHigh, 3))
            out.push({
                key: "nvme",
                text: `NVMe ${nvmeTemp} °C`,
                severe: nvmeTemp >= nvmeSevere
            });

        throttling = throttleSeenAt > 0 && now - throttleSeenAt < throttleHoldMs;
        if (throttling)
            out.push({
                key: "throttle",
                text: "CPU thermal throttling",
                severe: false
            });

        if (hasFan && above("fan", fan, fanHigh, 300)) {
            if (fanHighSince === 0)
                fanHighSince = now;
            if (now - fanHighSince >= fanHoldMs)
                out.push({
                    key: "fan",
                    text: `Fan ${fan} rpm`,
                    severe: false
                });
        } else
            fanHighSince = 0;

        for (const d of disks)
            if (d.free < (reasons.some(r => r.key === "disk" + d.mount) ? diskLow + 0.01 : diskLow))
                out.push({
                    key: "disk" + d.mount,
                    text: `${d.mount} ${Math.round(d.free * 100)}% free`,
                    severe: d.free < diskSevere
                });

        reasons = out;
    }
}
