import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Privacy indicator: one small dot per active category (screen share, mic,
// camera, remote session). Hidden when nothing is active; a dot lingers a
// few seconds after its source stops. Click lists who is using what.
BarButton {
    id: root

    readonly property var tints: ({
            screen: Theme.error,
            mic: Theme.warning,
            camera: Theme.success,
            remote: Theme.magenta
        })
    readonly property var icons: ({
            screen: "screen_share",
            mic: "mic",
            camera: "videocam",
            remote: "lan"
        })
    readonly property var names: ({
            screen: "Screen",
            mic: "Microphone",
            camera: "Camera",
            remote: "Remote"
        })

    visible: PrivacyState.any || pop.open
    active: pop.open
    tooltip: PrivacyState.items.filter(i => !i.ended).map(i => `${root.names[i.category]} · ${i.app}`).join("\n")
    onClicked: pop.toggle()

    // Dots sit in an icon-sized cell so one dot still has an icon's footprint.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(18, dots.width)
        height: 18

        Row {
            id: dots

            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: ScriptModel {
                    values: PrivacyState.categories
                }

                delegate: Rectangle {
                    required property string modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.tints[modelData]
                    opacity: PrivacyState.items.some(i => i.category === modelData && !i.ended) ? 1 : 0.45

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.medium
                        }
                    }
                }
            }
        }
    }

    component Entry: Rectangle {
        id: entry

        required property var modelData
        readonly property color tint: root.tints[modelData.category]
        readonly property bool mic: modelData.category === "mic"
        readonly property bool stoppable: modelData.sessionId !== null && !modelData.ended

        width: 320
        implicitHeight: 48
        radius: Theme.controlRadius
        color: "transparent"
        opacity: modelData.ended ? 0.5 : 1

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: Theme.alpha(entry.tint, 0.18)

            Icon {
                anchors.centerIn: parent
                name: entry.mic && entry.modelData.muted ? "mic_off" : root.icons[entry.modelData.category]
                size: 17
                fill: 1
                color: entry.tint
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: action.visible ? action.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: entry.modelData.app
                strong: true
            }
            Label {
                width: parent.width
                text: {
                    const when = Qt.formatTime(new Date(entry.modelData.since), "h:mm AP");
                    const state = entry.modelData.ended ? "ended" : `since ${when}`;
                    const extra = entry.mic && entry.modelData.muted ? " · source muted" : "";
                    return `${entry.modelData.what} · ${state}${extra}`;
                }
                muted: true
                font.pixelSize: Theme.smallSize
            }
        }

        BarButton {
            id: action

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.mic || entry.stoppable
            implicitWidth: 34
            implicitHeight: 34
            tooltip: entry.mic ? (Audio.micMuted ? "Unmute microphone" : "Mute microphone") : "Stop sharing"
            onClicked: entry.mic ? Audio.toggleMicMute() : PrivacyState.stopCast(entry.modelData)

            Icon {
                name: entry.mic ? (Audio.micMuted ? "mic" : "mic_off") : "stop_circle"
                size: 20
                color: entry.mic ? Theme.text : Theme.error
            }
        }
    }

    Popover {
        id: pop

        target: root

        Column {
            width: 320
            spacing: 2

            Label {
                text: "Privacy"
                strong: true
                font.pixelSize: Theme.titleSize
                bottomPadding: 6
            }
            Label {
                visible: !PrivacyState.any
                text: "Nothing is capturing or connected."
                muted: true
                bottomPadding: 4
            }

            Repeater {
                model: ScriptModel {
                    values: PrivacyState.items
                    objectProp: "id"
                }

                delegate: Entry {}
            }
        }
    }
}
