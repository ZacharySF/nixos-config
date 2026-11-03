import QtQuick
import Quickshell
import qs.config

// Hover hint below a bar item. Shown by BarButton after a short dwell.
PopupWindow {
    id: tip

    required property Item target
    property string text
    property bool shown: false

    anchor.item: target
    anchor.rect.x: target.width / 2
    anchor.rect.y: target.height + Theme.gap
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    visible: shown && text !== ""
    color: "transparent"
    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight

    Rectangle {
        id: bg

        implicitWidth: Math.min(label.implicitWidth, 420) + 20
        implicitHeight: label.implicitHeight + 12
        radius: Theme.controlRadius
        color: Theme.panelSolid

        Outline {
            radius: Theme.controlRadius
        }

        Label {
            id: label

            anchors.centerIn: parent
            width: Math.min(implicitWidth, 420)
            text: tip.text
            font.pixelSize: Theme.smallSize + 1
            maximumLineCount: 12
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeight: 1.15
        }
    }
}
