import QtQuick
import qs.config

// Quick-settings tile: icon + title + optional subtitle, filled when on.
// Click toggles via `toggled()`; the owner flips `checked` from real state.
Rectangle {
    id: tile

    property bool checked: false
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool busy: false

    signal toggled
    signal secondaryClicked

    implicitWidth: 150
    implicitHeight: subtitle !== "" ? 52 : 42
    radius: Theme.controlRadius + 4
    color: checked ? Theme.accent : mouse.containsMouse ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.07)

    Behavior on color {
        ColorAnimation {
            duration: Theme.medium
            easing.type: Theme.easing
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: tile.icon
            fill: tile.checked ? 1 : 0
            color: tile.checked ? Theme.accentText : Theme.text
            opacity: tile.busy ? 0.5 : 1
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 28 - parent.spacing

            Label {
                width: parent.width
                text: tile.title
                strong: true
                color: tile.checked ? Theme.accentText : Theme.text
            }
            Label {
                width: parent.width
                visible: tile.subtitle !== ""
                text: tile.subtitle
                font.pixelSize: Theme.smallSize
                color: tile.checked ? Theme.alpha(Theme.accentText, 0.75) : Theme.textMuted
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? tile.secondaryClicked() : tile.toggled()
    }
}
