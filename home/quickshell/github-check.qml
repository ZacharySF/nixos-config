import QtQuick
import Quickshell
import qs.bar
ShellRoot {
    Github { id: button }
    Timer {
        interval: 500
        running: true
        onTriggered: {
            if (button.url.toString() !== "https://github.com/zacharysf") Qt.exit(1);
            else { console.log("PASS: GitHub button targets ZacharySF"); Qt.exit(0); }
        }
    }
}
