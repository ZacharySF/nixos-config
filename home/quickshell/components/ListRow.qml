import QtQuick
import qs.config

// Popover list row: leading icon, title + optional subtitle, trailing text
// or icon. Hover highlights; click emits `clicked`.
Rectangle {
    id: row

    property string icon: ""
    property color iconColor: Theme.text
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property string trailingIcon: ""
    property bool highlighted: false
    property bool interactive: true

    signal clicked

    implicitWidth: 300
    implicitHeight: subtitle !== "" ? 46 : 36
    radius: Theme.controlRadius
    color: highlighted ? Theme.alpha(Theme.accent, 0.16) : (interactive && mouse.containsMouse) ? Theme.hover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Icon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: row.icon !== ""
        name: row.icon
        color: row.highlighted ? Theme.accent : row.iconColor
        fill: row.highlighted ? 1 : 0
    }

    Column {
        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? 10 : 8
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Label {
            width: parent.width
            text: row.title
        }
        Label {
            width: parent.width
            visible: row.subtitle !== ""
            text: row.subtitle
            muted: true
            font.pixelSize: Theme.smallSize
        }
    }

    Item {
        id: tail

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(tailText.visible ? tailText.implicitWidth : 0, tailIcon.visible ? tailIcon.implicitWidth : 0)
        height: parent.height

        Label {
            id: tailText

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.trailing !== ""
            text: row.trailing
            muted: true
            font.pixelSize: Theme.smallSize + 1
        }
        Icon {
            id: tailIcon

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.trailingIcon !== ""
            name: row.trailingIcon
            size: 16
            color: Theme.textMuted
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: row.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
