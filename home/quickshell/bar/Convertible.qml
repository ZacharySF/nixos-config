import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Convertible controls. Laptop: one mode glyph with a small badge while a
// lock (mode or rotation) is set; click for the menu. Tablet: the keyboard
// and rotation lock also become their own touch buttons.
Row {
    id: root

    spacing: 2

    BarButton {
        id: mode

        active: pop.open
        tooltip: (Toggles.tabletMode ? "Tablet mode" : "Laptop mode") + (Toggles.modeLock !== "auto" ? " · locked" : "") + (Toggles.rotationLocked ? "\nRotation locked" : "")
        onClicked: pop.toggle()

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSize
            height: Theme.iconSize

            Icon {
                anchors.centerIn: parent
                name: Toggles.tabletMode ? "tablet" : "laptop"
            }
            Rectangle {
                visible: Toggles.modeLock !== "auto" || Toggles.rotationLocked
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -1
                anchors.topMargin: -1
                width: 7
                height: 7
                radius: 3.5
                color: Theme.warning
                border.width: 1.5
                border.color: Theme.surfaceContainer
            }
        }

        Popover {
            id: pop

            target: mode
            onOpenChanged: if (open) Toggles.refresh()

            Column {
                width: 300
                spacing: 8

                SectionLabel {
                    text: "Mode"
                }
                Segmented {
                    width: parent.width
                    current: Toggles.modeLock
                    options: [
                        {
                            value: "auto",
                            label: "Auto",
                            icon: "sync"
                        },
                        {
                            value: "laptop",
                            label: "Laptop",
                            icon: "laptop"
                        },
                        {
                            value: "tablet",
                            label: "Tablet",
                            icon: "tablet_android"
                        }
                    ]
                    onSelected: v => Toggles.setMode(v)
                }
                Label {
                    width: parent.width
                    text: Toggles.modeLock === "auto" ? "Follows the hinge." : "Locked until you pick Auto or log out."
                    muted: true
                    font.pixelSize: Theme.smallSize
                }

                Item {
                    width: 1
                    height: 2
                }
                Row {
                    spacing: 8

                    Toggle {
                        width: 146
                        icon: "screen_lock_rotation"
                        title: "Rotation"
                        subtitle: Toggles.rotationLocked ? "Locked" : "Auto"
                        checked: Toggles.rotationLocked
                        onToggled: Toggles.toggleRotationLock()
                    }
                    Toggle {
                        width: 146
                        icon: "keyboard"
                        title: "Keyboard"
                        subtitle: Toggles.oskRunning ? "Shown" : "Hidden"
                        checked: Toggles.oskRunning
                        onToggled: Toggles.toggleOsk()
                    }
                }
            }
        }
    }

    BarButton {
        visible: Theme.tablet
        tooltip: "On-screen keyboard"
        active: Toggles.oskRunning
        onClicked: Toggles.toggleOsk()

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
        }
    }
    BarButton {
        visible: Theme.tablet
        tooltip: Toggles.rotationLocked ? "Unlock rotation" : "Lock rotation"
        active: Toggles.rotationLocked
        onClicked: Toggles.toggleRotationLock()

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Toggles.rotationLocked ? "screen_lock_rotation" : "screen_rotation"
        }
    }
}
