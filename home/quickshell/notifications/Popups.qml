import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Notification popups, top-right under the bar on the focused output.
// Cards slide in from the edge, can be swiped right to dismiss, and pause
// their timeout while hovered. Up to four are shown at once.
PanelWindow {
    id: win

    readonly property real margin: Theme.shadowEnabled ? Theme.shadowBlur : 8
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]

    screen: focusedScreen
    visible: !Notifications.centerOpen && (Notifications.popupEntries.length > 0 || linger.running)
    anchors {
        top: !Config.dev
        bottom: Config.dev
        right: true
    }
    margins.top: Config.dev ? 0 : Theme.barHeight + Theme.gap * 2 - margin
    margins.bottom: Config.dev ? Theme.barHeight + Theme.gap * 2 + Config.devOffset : 0
    margins.right: Theme.gap - margin
    implicitWidth: 380 + margin * 2
    implicitHeight: Math.max(1, list.contentHeight + margin * 2)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: Config.namespace + "-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    mask: Region {
        Region {
            item: list.count > 0 ? list.itemAtIndex(0) : null
        }
        Region {
            item: list.count > 1 ? list.itemAtIndex(1) : null
        }
        Region {
            item: list.count > 2 ? list.itemAtIndex(2) : null
        }
        Region {
            item: list.count > 3 ? list.itemAtIndex(3) : null
        }
    }

    // Keep the surface alive while the last card animates out.
    Timer {
        id: linger

        interval: 500
    }
    Connections {
        target: Notifications
        function onPopupEntriesChanged() {
            linger.restart();
        }
    }

    ListView {
        id: list

        x: win.margin
        y: win.margin
        width: 380
        height: contentHeight
        interactive: false
        spacing: Theme.gap
        verticalLayoutDirection: Config.dev ? ListView.BottomToTop : ListView.TopToBottom

        model: ScriptModel {
            values: Notifications.popupEntries
            objectProp: "key"
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.fast
                }
                NumberAnimation {
                    property: "x"
                    from: 60
                    to: 0
                    duration: Theme.slow
                    easing.type: Theme.easing
                }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.fast
                }
                NumberAnimation {
                    property: "x"
                    to: 120
                    duration: Theme.medium
                    easing.type: Easing.InCubic
                }
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.medium
                easing.type: Theme.easing
            }
        }

        delegate: Item {
            id: slot

            required property var modelData
            width: 380
            height: card.height

            NotificationCard {
                id: card

                entry: slot.modelData
                width: 380
                timeout: slot.modelData.urgency === 2 ? 0 : (slot.modelData.notif?.expireTimeout > 0 ? Math.max(2500, slot.modelData.notif.expireTimeout) : slot.modelData.urgency === 0 ? 3500 : 6000)
                onTimedOut: Notifications.hidePopup(slot.modelData.key)

                layer.enabled: Theme.shadowEnabled
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.alpha(Theme.shadow, Theme.shadowOpacity)
                    shadowBlur: 1.0
                    blurMax: Math.round(Theme.shadowBlur)
                    shadowVerticalOffset: Theme.shadowOffsetY
                }

                transform: Translate {
                    id: swipe
                }

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onTranslationChanged: swipe.x = Math.max(0, translation.x)
                    onActiveChanged: {
                        if (active)
                            return;
                        if (swipe.x > card.width * 0.35)
                            Notifications.hidePopup(slot.modelData.key);
                        else
                            settle.restart();
                    }
                }

                NumberAnimation {
                    id: settle

                    target: swipe
                    property: "x"
                    to: 0
                    duration: Theme.medium
                    easing.type: Theme.easing
                }
            }
        }
    }
}
