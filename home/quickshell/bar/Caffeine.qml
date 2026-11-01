import QtQuick
import qs.components
import qs.config
import qs.services

// Caffeine (caffeine-toggle): off -> lid (no suspend on lid close) ->
// full (also no idle lock) -> off. Click cycles, right-click turns it off.
BarButton {
    id: root

    readonly property string mode: Toggles.caffeine

    tooltip: mode === "lid" ? "Caffeine: lid close won't suspend" : mode === "full" ? "Caffeine: no suspend, no idle lock" : "Caffeine off · click to keep awake"
    onClicked: Toggles.cycleCaffeine()
    onRightClicked: Toggles.caffeineOff()

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize

        // The one bar icon where fill carries state: outline cup = off,
        // filled cup = on (the dot adds "no idle lock").
        Icon {
            anchors.centerIn: parent
            name: "coffee"
            fill: root.mode === "off" ? 0 : 1
            color: root.mode === "off" ? Theme.textMuted : Theme.text
        }
        // Full mode also blocks the idle lock: mark it with the accent dot.
        Rectangle {
            visible: root.mode === "full"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -1
            anchors.topMargin: -1
            width: 7
            height: 7
            radius: 3.5
            color: Theme.accent
            border.width: 1.5
            border.color: Theme.surfaceContainer
        }
    }
}
