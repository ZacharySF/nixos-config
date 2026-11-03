import QtQuick
import qs.config

// Segmented control: one of N options. `options` is [{ value, label, icon }];
// `selected(value)` fires on click and the owner updates `current`.
Rectangle {
    id: seg

    property var options: []
    property var current
    signal selected(var value)

    implicitWidth: 300
    implicitHeight: 36
    radius: Theme.controlRadius + 2
    color: Theme.alpha(Theme.text, 0.07)

    readonly property int currentIndex: options.findIndex(o => o.value === current)

    Rectangle {
        visible: seg.currentIndex >= 0
        x: 3 + seg.currentIndex * (seg.width - 6) / Math.max(1, seg.options.length)
        y: 3
        width: (seg.width - 6) / Math.max(1, seg.options.length)
        height: seg.height - 6
        radius: Theme.controlRadius
        color: Theme.accent

        Behavior on x {
            NumberAnimation {
                duration: Theme.medium
                easing.type: Theme.easing
            }
        }
    }

    Row {
        x: 3
        y: 3

        Repeater {
            model: seg.options

            delegate: Item {
                id: opt

                required property var modelData
                required property int index
                readonly property bool on: index === seg.currentIndex

                width: (seg.width - 6) / Math.max(1, seg.options.length)
                height: seg.height - 6

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (opt.modelData.icon ?? "") !== ""
                        name: opt.modelData.icon ?? ""
                        size: 16
                        fill: opt.on ? 1 : 0
                        color: opt.on ? Theme.accentText : Theme.text
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (opt.modelData.label ?? "") !== ""
                        text: opt.modelData.label ?? ""
                        font.pixelSize: Theme.smallSize + 1
                        color: opt.on ? Theme.accentText : Theme.text
                        strong: opt.on
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.selected(opt.modelData.value)
                }
            }
        }
    }
}
