import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Windows parked on the "stash" workspace by niri-scratchpad. Hidden while
// the stash is empty; the popover lists them and summons one on click.
BarButton {
    id: root

    readonly property var stashed: Niri.stashWindows

    visible: stashed.length > 0
    active: pop.open
    tooltip: stashed.length === 1 ? "1 window in the scratchpad" : `${stashed.length} windows in the scratchpad`
    onClicked: pop.toggle()

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "inventory_2"
        size: 16
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.stashed.length
    }

    Popover {
        id: pop

        target: root

        Column {
            spacing: 2
            width: 300

            Label {
                text: "Scratchpad"
                strong: true
                font.pixelSize: Theme.titleSize
                bottomPadding: 6
            }

            Repeater {
                model: root.stashed

                delegate: BarButton {
                    id: item

                    required property var modelData
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.app_id ?? "")

                    width: 300
                    implicitHeight: 36
                    onClicked: {
                        Niri.summonWindow(modelData.id);
                        pop.open = false;
                    }

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        sourceSize.width: 40
                        sourceSize.height: 40
                        source: {
                            const c = item.entry?.icon ?? item.modelData.app_id ?? "";
                            return c && Quickshell.hasThemeIcon(c) ? Quickshell.iconPath(c) : "";
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 240
                        text: item.modelData.title || item.modelData.app_id
                    }
                }
            }
        }
    }
}
