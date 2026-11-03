pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery and pen battery, read from sysfs.
// One read of BAT0/uevent carries status,
// capacity, instantaneous draw and the energy counters. Plug/unplug edges
// arrive through `udevadm monitor`, so on AC with a full battery nothing
// polls beyond the once-a-minute history sample; while charging or
// discharging the uevent is re-read every 3 s for the live draw.
//
// The ETA regresses the energy counter over a trailing 5-minute window
// (the same estimator waybar-battery used: power_now alone is too jumpy
// and UPower's smoothing is skipped for batteries that report it). Until
// two minutes of samples exist the instantaneous draw stands in.
//
Singleton {
    id: root

    readonly property string batteryDir: "/sys/class/power_supply/BAT0"

    // --- Battery (sysfs wording for status) --------------------------------
    property bool available: false
    property string status: "Unknown"
    property int percent: 0
    property real powerNow: 0 // W, instantaneous
    property real energyNow: 0 // Wh
    property real energyFull: 0
    property real energyDesign: 0
    property int cycles: -1
    property bool acOnline: false

    readonly property bool charging: status === "Charging"
    readonly property bool discharging: status === "Discharging"
    readonly property bool full: status === "Full" || status === "Not charging"
    readonly property bool critical: discharging && percent < 10
    readonly property real health: energyDesign > 0 ? energyFull / energyDesign : 0

    // --- Rate and ETA -------------------------------------------------------
    // rate: W over the regression window, 0 while warming up.
    // secondsLeft: to empty while discharging, to full while charging, -1 unknown.
    property real rate: 0
    property int secondsLeft: -1
    readonly property bool estimating: (charging || discharging) && secondsLeft < 0

    // --- History: one {t (ms), pct, charging} per minute, last 6 h ---------
    property var history: []
    readonly property int historyWindowMs: 6 * 3600 * 1000

    // --- Pen (HID battery of the stylus; reports only once the pen is seen)
    property string penDir: ""
    property bool penPresent: false
    property int penPercent: -1

    function refresh() {
        bat.reload();
        ac.reload();
        if (penDir !== "")
            pen.reload();
    }

    // --- Formatting helpers shared by bar and popover ----------------------
    function formatDuration(secs) {
        if (secs < 0)
            return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        if (h === 0)
            return `${Math.max(1, m)} min`;
        return m === 0 ? `${h} h` : `${h} h ${m} min`;
    }

    function formatWatts(w) {
        return w >= 10 ? `${w.toFixed(0)} W` : `${w.toFixed(1)} W`;
    }

    // --- sysfs -------------------------------------------------------------
    function parseUevent(text) {
        const out = {};
        for (const line of text.split("\n")) {
            const eq = line.indexOf("=");
            if (eq > 0)
                out[line.slice(0, eq)] = line.slice(eq + 1);
        }
        return out;
    }

    FileView {
        id: bat

        path: root.batteryDir + "/uevent"
        onLoaded: root.readBattery(root.parseUevent(text()))
        onLoadFailed: root.available = false
    }

    FileView {
        id: ac

        path: "/sys/class/power_supply/AC/uevent"
        onLoaded: root.acOnline = root.parseUevent(text()).POWER_SUPPLY_ONLINE === "1"
        onLoadFailed: root.acOnline = false
    }

    FileView {
        id: pen

        path: root.penDir !== "" ? root.penDir + "/uevent" : ""
        onLoaded: {
            const u = root.parseUevent(text());
            const level = parseInt(u.POWER_SUPPLY_CAPACITY ?? "0") || 0;
            root.penPresent = u.POWER_SUPPLY_PRESENT === "1" || level > 0;
            root.penPercent = root.penPresent ? level : -1;
        }
        onLoadFailed: {
            root.penPresent = false;
            root.penPercent = -1;
        }
    }

    // The HID node carries the device instance in its name
    // (hid-0018:04F3:4301.0002-battery-7), which can change across boots.
    Process {
        running: true
        command: ["ls", "/sys/class/power_supply"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hid = text.split("\n").find(n => n.startsWith("hid-"));
                root.penDir = hid ? "/sys/class/power_supply/" + hid : "";
                if (hid)
                    pen.reload();
            }
        }
    }

    function readBattery(u) {
        available = true;
        status = u.POWER_SUPPLY_STATUS ?? "Unknown";
        percent = parseInt(u.POWER_SUPPLY_CAPACITY ?? "0") || 0;
        powerNow = (parseInt(u.POWER_SUPPLY_POWER_NOW ?? "0") || 0) / 1e6;
        energyNow = (parseInt(u.POWER_SUPPLY_ENERGY_NOW ?? "0") || 0) / 1e6;
        energyFull = (parseInt(u.POWER_SUPPLY_ENERGY_FULL ?? "0") || 0) / 1e6;
        energyDesign = (parseInt(u.POWER_SUPPLY_ENERGY_FULL_DESIGN ?? "0") || 0) / 1e6;
        cycles = u.POWER_SUPPLY_CYCLE_COUNT !== undefined ? parseInt(u.POWER_SUPPLY_CYCLE_COUNT) : -1;
        const now = Date.now();
        updateRate(now / 1000);
        if (history.length === 0 || now - history[history.length - 1].t >= 59000)
            sample(now);
    }

    // --- Rate regression ---------------------------------------------------
    property var samples: [] // [[t (s), Wh], ...], 5-minute window
    property string samplesStatus: ""

    function updateRate(now) {
        let s = samples;
        if (samplesStatus !== status || (s.length > 0 && now - s[s.length - 1][0] > 120)) {
            s = [];
            samplesStatus = status;
        }
        if (!charging && !discharging) {
            samples = [];
            rate = 0;
            secondsLeft = -1;
            return;
        }
        s = s.concat([[now, energyNow]]);
        while (s.length > 2 && now - s[0][0] > 300)
            s = s.slice(1);
        samples = s;

        let r = 0;
        const n = s.length;
        const span = n > 1 ? s[n - 1][0] - s[0][0] : 0;
        if (span >= 120) {
            const secant = (s[0][1] - s[n - 1][1]) / span * 3600;
            let mt = 0, me = 0;
            for (const [t, e] of s) {
                mt += t;
                me += e;
            }
            mt /= n;
            me /= n;
            let sxx = 0, sxy = 0;
            for (const [t, e] of s) {
                sxx += (t - mt) * (t - mt);
                sxy += (t - mt) * (e - me);
            }
            const recent = sxx > 0 ? -(sxy / sxx) * 3600 : secant;
            r = Math.abs(span < 300 ? secant : 0.7 * recent + 0.3 * secant);
            if (r < 0.1 || r > 300)
                r = 0;
        }
        rate = r;
        const use = r > 0 ? r : powerNow;
        if (use < 0.1 || energyFull <= 0) {
            secondsLeft = -1;
            return;
        }
        let secs;
        if (charging) {
            // Constant current up to the knee, then a tapering CV phase.
            const knee = 0.8 * energyFull;
            const cc = Math.max(0, knee - energyNow);
            const cv = Math.max(0, energyFull - Math.max(energyNow, knee));
            secs = 3600 * (cc / use + cv / (0.45 * use));
        } else {
            // The pack cuts off around 4%.
            secs = 3600 * Math.max(0, energyNow - 0.04 * energyFull) / use;
        }
        secondsLeft = secs > 86400 ? -1 : Math.round(secs);
    }

    function sample(now) {
        history = history.filter(p => now - p.t <= historyWindowMs).concat([
            {
                t: now,
                pct: percent,
                charging: charging || full
            }
        ]);
    }

    // --- Cadence -----------------------------------------------------------
    Timer {
        interval: 3000
        repeat: true
        running: root.available && (root.charging || root.discharging)
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.available
        onTriggered: root.refresh()
    }

    // Plug/unplug edges without polling.
    Process {
        id: udev

        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("(power_supply)"))
                    debounce.restart();
            }
        }
    }

    Timer {
        id: debounce

        interval: 300
        onTriggered: root.refresh()
    }
}
