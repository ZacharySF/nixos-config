import QtQuick
import qs.config

// One floating bar section. In "strip" layout the islands lose their own
// surface and sit on the bar-wide strip instead; content and spacing stay.
Rectangle {
    id: island

    default property alias content: row.data
    // Same inset on every side: items are barHeight - 8 tall, centered, so
    // 4 px top/bottom; matching it left/right makes a one-item island square.
    property real padding: 4
    // Blur target, inset so the compositor's stair-stepped region edge sits
    // under the antialiased surface and outline instead of outside them.
    readonly property alias blurArea: blurTarget

    readonly property bool empty: row.implicitWidth <= 0

    implicitWidth: empty ? 0 : row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    visible: !empty || opacity > 0
    opacity: empty ? 0 : 1
    radius: Theme.radius
    color: Theme.islands ? Theme.panel : "transparent"
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.medium
            easing.type: Theme.easing
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fast
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.medium
        }
    }

    Item {
        id: blurTarget

        anchors.fill: parent
        anchors.margins: 1.5
    }

    Outline {
        visible: Theme.islands
    }

    Row {
        id: row

        x: island.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
    }
}
