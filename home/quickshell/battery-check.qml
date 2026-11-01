import QtQuick
import Quickshell
import qs.bar
import qs.services

ShellRoot {
    Battery { id: battery }
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            const labels = Array.from(battery.content).filter(item => item.text !== undefined);
            const expected = `${Power.percent}%`;
            if (!labels.some(item => item.text === expected)) {
                console.error(`FAIL: battery bar has no visible ${expected} label`);
                Qt.exit(1);
            } else {
                console.log(`PASS: battery bar shows ${expected}`);
                Qt.exit(0);
            }
        }
    }
}
