import QtQuick
import Quickshell
import qs.components

// Shown only while an external display is connected; opens the
// niri-monitor-switch menu (extend, mirror, external only, internal only).
BarButton {
    visible: Quickshell.screens.length > 1
    tooltip: "Display layout"
    onClicked: Quickshell.execDetached(["niri-monitor-switch"])

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "desktop_windows"
    }
}
