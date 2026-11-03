import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.bar
import qs.config
ShellRoot {
    Tray { id: tray }
    Timer {
        interval: 1200
        running: true
        onTriggered: {
            let failed = Theme.iconSize !== 16 || Theme.textSize !== 12 || Theme.gap !== 6;
            for (const item of SystemTray.items.values) console.log(`TRAY: ${item.id} | ${item.title}`);
            for (const child of tray.children) {
                if (child.modelData && /blueman/i.test(child.modelData.id) && child.visible) failed = true;
            }
            console.log(failed ? "FAIL: compact sizing or Bluetooth tray visibility" : "PASS: compact sizing and Bluetooth tray hidden");
            Qt.exit(failed ? 1 : 0);
        }
    }
}
