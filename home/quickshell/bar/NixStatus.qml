import QtQuick
import qs.components
import qs.config
import qs.services

// Nix: hidden unless a build is running, a newer generation is built but not
// active, or the running kernel differs from the booted one. The popover
// shows the generation and flake input ages.
BarButton {
    id: root

    readonly property string headline: NixState.building > 0 ? (NixState.building === 1 ? "Building 1 derivation" : `Building ${NixState.building} derivations`) : NixState.rebootPending ? "Reboot to use the new kernel" : NixState.switchPending ? "New generation not switched to" : ""

    visible: NixState.shown || pop.open
    active: pop.open
    tooltip: headline
    onClicked: pop.toggle()

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize
        height: Theme.iconSize

        Icon {
            id: glyph

            anchors.centerIn: parent
            name: NixState.building > 0 ? "progress_activity" : NixState.rebootPending ? "restart_alt" : "deployed_code_update"

            // Stepped, not animated: 45° four times a second costs four
            // frames per second instead of a redraw on every display refresh
            // for the length of a build.
            Timer {
                running: NixState.building > 0 && root.visible
                interval: 250
                repeat: true
                onTriggered: glyph.rotation = (glyph.rotation + 45) % 360
                onRunningChanged: if (!running) glyph.rotation = 0
            }
        }
        Rectangle {
            visible: NixState.building === 0 && (NixState.switchPending || NixState.rebootPending)
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

        target: root

        Column {
            width: 320
            spacing: 6

            Label {
                text: "NixOS"
                strong: true
                font.pixelSize: Theme.titleSize
            }
            Label {
                visible: root.headline !== ""
                width: parent.width
                text: root.headline
                muted: true
                wrapMode: Text.Wrap
            }
            ListRow {
                width: parent.width
                interactive: false
                icon: "history"
                title: `Generation ${NixState.currentGeneration}`
                subtitle: NixState.currentVersion
                trailing: Qt.formatDate(NixState.currentDate, "MMM d")
            }
            ListRow {
                width: parent.width
                interactive: false
                visible: NixState.containers > 0
                icon: "deployed_code"
                title: "Podman"
                trailing: NixState.containers === 1 ? "1 running" : `${NixState.containers} running`
            }

            SectionLabel {
                text: "Flake inputs"
            }
            Repeater {
                model: NixState.inputs

                delegate: Item {
                    required property var modelData

                    width: 320
                    height: 24

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 220
                        text: modelData.name
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.days === 0 ? "today" : modelData.days === 1 ? "1 day" : `${modelData.days} days`
                        color: modelData.stale ? Theme.warning : Theme.textMuted
                        font.pixelSize: Theme.smallSize + 1
                    }
                }
            }
        }
    }
}
