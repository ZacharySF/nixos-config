import QtQuick
import Quickshell
import qs.components
import qs.config

// Accent dot at the far left opens the desktop's application launcher.
BarButton {
    id: root

    padding: 6
    tooltip: "Applications"
    onClicked: Quickshell.execDetached(["fuzzel"])
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14

        Rectangle {
            anchors.centerIn: parent
            width: root.hovered ? 13 : 10
            height: width
            radius: width / 2
            color: Theme.accent

            Behavior on width {
                NumberAnimation {
                    duration: Theme.medium
                    easing.type: Theme.easing
                }
            }
        }
    }
}
