import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.config
import qs.notifications
import qs.services

// Bell + notification center. Badge = unread normal/critical notifications.
// Right-click toggles Do Not Disturb. `qs ipc call notifications toggleCenter`
// opens the center on the focused output.
BarButton {
    id: root

    required property string output

    readonly property int unread: Notifications.unread
    readonly property string glyph: Notifications.dnd ? "notifications_off" : Notifications.pauseReason !== "" ? "notifications_paused" : unread > 0 ? "notifications_unread" : "notifications"

    active: pop.open
    tooltip: Notifications.pauseReason !== "" ? Notifications.pauseReason : unread > 0 ? (unread === 1 ? "1 unread notification" : `${unread} unread notifications`) : "No new notifications"
    onClicked: pop.toggle()
    onRightClicked: Notifications.dnd = !Notifications.dnd

    Connections {
        target: Notifications
        function onCenterRequested() {
            if (Niri.focusedWorkspace?.output === root.output)
                pop.toggle();
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize

        Icon {
            anchors.centerIn: parent
            name: root.glyph
            color: Notifications.pauseReason !== "" ? Theme.textMuted : Theme.text
        }
        Rectangle {
            visible: root.unread > 0 && !Notifications.dnd
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

    Popover {
        id: pop

        target: root
        onOpenChanged: {
            Notifications.centerOpen = open;
            if (!open)
                Notifications.markAllRead();
        }

        Column {
            width: 380
            spacing: 10

            Item {
                width: parent.width
                height: 32

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    strong: true
                    font.pixelSize: Theme.titleSize
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    BarButton {
                        implicitHeight: 30
                        active: Notifications.dnd
                        tooltip: Notifications.dnd ? "Turn off Do Not Disturb" : "Do Not Disturb"
                        onClicked: Notifications.dnd = !Notifications.dnd

                        Icon {
                            name: "do_not_disturb_on"
                            fill: Notifications.dnd ? 1 : 0
                            color: Notifications.dnd ? Theme.accent : Theme.text
                        }
                    }
                    BarButton {
                        implicitHeight: 30
                        visible: Notifications.entries.length > 0
                        onClicked: Notifications.clearAll()

                        Label {
                            text: "Clear"
                            font.pixelSize: Theme.smallSize + 1
                        }
                    }
                }
            }

            Label {
                visible: Notifications.pauseReason !== "" && !Notifications.dnd
                text: Notifications.pauseReason
                muted: true
                font.pixelSize: Theme.smallSize + 1
            }

            // Empty state.
            Column {
                visible: Notifications.entries.length === 0
                width: parent.width
                topPadding: 24
                bottomPadding: 28
                spacing: 8

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "notifications"
                    size: 30
                    color: Theme.alpha(Theme.textMuted, 0.6)
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing new"
                    muted: true
                }
            }

            ScrollView {
                id: scroller

                visible: Notifications.entries.length > 0
                width: parent.width
                height: Math.min(groups.implicitHeight, 560)
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    id: groups

                    width: scroller.availableWidth
                    spacing: 14

                    Repeater {
                        model: ScriptModel {
                            objectProp: "app"
                            values: {
                                const order = [];
                                const byApp = {};
                                for (const e of Notifications.entries) {
                                    const app = e.appName || "Other";
                                    if (!byApp[app]) {
                                        byApp[app] = [];
                                        order.push(app);
                                    }
                                    byApp[app].push(e);
                                }
                                return order.map(app => ({
                                            app,
                                            items: byApp[app]
                                        }));
                            }
                        }

                        delegate: Column {
                            id: group

                            required property var modelData
                            property bool expanded: false
                            readonly property bool muted: Notifications.isMuted(modelData.app)

                            width: groups.width
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 22

                                HoverHandler {
                                    id: headerHover
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: group.modelData.app + (group.muted ? "  · muted" : "")
                                    muted: true
                                    strong: true
                                    font.pixelSize: Theme.smallSize
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    BarButton {
                                        implicitHeight: 22
                                        padding: 4
                                        opacity: group.muted || headerHover.hovered ? 1 : 0
                                        tooltip: group.muted ? "Unmute this app" : "Mute this app"
                                        onClicked: Notifications.toggleMute(group.modelData.app)

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.fast
                                            }
                                        }


                                        Icon {
                                            name: group.muted ? "volume_off" : "notifications_active"
                                            size: 14
                                            color: Theme.textMuted
                                        }
                                    }
                                    BarButton {
                                        implicitHeight: 22
                                        padding: 4
                                        visible: group.modelData.items.length > 3
                                        onClicked: group.expanded = !group.expanded

                                        Label {
                                            text: group.expanded ? "Less" : `+${group.modelData.items.length - 3}`
                                            font.pixelSize: Theme.smallSize
                                            muted: true
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: ScriptModel {
                                    objectProp: "key"
                                    values: group.expanded ? group.modelData.items : group.modelData.items.slice(0, 3)
                                }

                                delegate: NotificationCard {
                                    required property var modelData

                                    entry: modelData
                                    compact: true
                                    width: group.width
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
