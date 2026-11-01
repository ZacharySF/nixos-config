import QtQuick
import qs.config

// Hoverable, clickable bar item. Content goes into a centered Row.
Item {
    id: btn

    default property alias content: row.data
    property real padding: 6
    property bool active: false
    property bool interactive: true
    property string tooltip: ""
    property alias hovered: mouse.containsMouse
    property alias spacing: row.spacing

    signal clicked
    signal middleClicked
    signal rightClicked
    signal scrolled(int delta)

    implicitWidth: Math.max(implicitHeight, row.implicitWidth + padding * 2)
    implicitHeight: Theme.barHeight - 8

    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: mouse.pressed ? Theme.pressed : (btn.active || (mouse.containsMouse && btn.interactive)) ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: btn.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => {
            tipTimer.stop();
            tip.shown = false;
            if (m.button === Qt.MiddleButton)
                btn.middleClicked();
            else if (m.button === Qt.RightButton)
                btn.rightClicked();
            else
                btn.clicked();
        }
        onWheel: w => {
            const d = w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x;
            if (d !== 0)
                btn.scrolled(d > 0 ? 1 : -1);
        }
        onContainsMouseChanged: {
            if (containsMouse && btn.tooltip !== "")
                tipTimer.restart();
            else {
                tipTimer.stop();
                tip.shown = false;
            }
        }
    }

    Timer {
        id: tipTimer

        interval: 550
        onTriggered: tip.shown = true
    }

    Tooltip {
        id: tip

        target: btn
        text: btn.tooltip
    }
}
