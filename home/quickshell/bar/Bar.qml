import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// One bar per output: left (niri), center (time), right (status) islands.
// Theme.islands switches between separate floating islands and a single
// continuous strip without changing the widgets.
PanelWindow {
    id: bar

    required property ShellScreen modelData

    // Portrait (or any narrow) screen: secondary items collapse so the
    // three islands still fit side by side.
    readonly property bool narrow: (Config.devWidth > 0 ? Config.devWidth : width) < 1100

    screen: modelData
    anchors {
        top: !Config.dev
        bottom: Config.dev
        left: true
        right: Config.devWidth === 0
    }
    implicitWidth: Config.devWidth
    implicitHeight: Theme.barHeight + Theme.gap
    exclusionMode: Config.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    margins.bottom: Config.dev ? Config.devOffset : 0
    exclusiveZone: Config.dev ? 0 : Theme.barHeight + Theme.gap
    color: "transparent"
    WlrLayershell.namespace: Config.namespace
    WlrLayershell.layer: WlrLayer.Top

    BackgroundEffect.blurRegion: Region {
        Region {
            item: Theme.islands ? leftIsland.blurArea : stripBlur
            radius: Theme.radius - 1.5
        }
        Region {
            item: Theme.islands && !centerIsland.empty ? centerIsland.blurArea : null
            radius: Theme.radius - 1.5
        }
        Region {
            item: Theme.islands && !rightIsland.empty ? rightIsland.blurArea : null
            radius: Theme.radius - 1.5
        }
    }

    Item {
        id: content

        x: Theme.gap
        y: Config.dev ? 0 : Theme.gap
        width: parent.width - Theme.gap * 2
        height: Theme.barHeight

        Rectangle {
            id: stripBg

            anchors.fill: parent
            visible: !Theme.islands
            radius: Theme.radius
            color: Theme.panel

            Item {
                id: stripBlur

                anchors.fill: parent
                anchors.margins: 1.5
            }

            Outline {}
        }

        Island {
            id: leftIsland

            anchors.left: parent.left

            Launcher {}
            Github {}
            // Touch has no hot corner or Mod key: an explicit overview button.
            BarButton {
                visible: Theme.tablet
                tooltip: "Overview"
                active: Niri.overviewOpen
                onClicked: Niri.toggleOverview()

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "grid_view"
                    fill: Niri.overviewOpen ? 1 : 0
                }
            }
            FocusedWindow {
                narrow: bar.narrow
            }
        }

        Island {
            id: centerIsland

            // Whole-pixel position keeps the hairline outline crisp.
            x: Math.round(Math.max(leftIsland.width + Theme.gap, Math.min((parent.width - width) / 2, rightIsland.x - Theme.gap - width)))
            // Never draw over a neighbour: if even the collapsed layout has
            // no room for it, leave the space empty rather than overlap.
            visible: !empty && leftIsland.width + Theme.gap * 2 + implicitWidth <= rightIsland.x

            NowPlaying {
                narrow: bar.narrow
            }
            Clock {}
            Privacy {}
        }

        Island {
            id: rightIsland

            anchors.right: parent.right

            Agents {}
            Health {
                narrow: bar.narrow
            }
            Tray {}
            Chip {
                NetStatus {}
                Volume {}
                Battery {}
            }
        }
    }
}
