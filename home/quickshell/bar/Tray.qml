import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config

// StatusNotifierItem tray. Passive items stay hidden, the widget disappears
// when nothing is left. Icons are tinted to the text color so they sit
// with the Material glyphs; an item asking for attention gets the badge
// dot. Left-click activates (or opens the menu for menu-only items),
// middle-click is the secondary action, scrolling is passed through,
// right-click opens the item's menu rendered in the bar's popover style.
Row {
    id: root

    // Positioners skip hidden children, so an all-passive tray has no width.
    visible: implicitWidth > 0
    spacing: 2

    Repeater {
        model: SystemTray.items

        delegate: BarButton {
            id: button

            required property SystemTrayItem modelData
            readonly property bool attention: modelData.status === Status.NeedsAttention

            visible: modelData.status !== Status.Passive && modelData.id !== "blueman"
            tooltip: modelData.tooltipTitle || modelData.title || modelData.id
            active: menu.open
            onClicked: {
                if (modelData.onlyMenu)
                    menu.toggle();
                else
                    modelData.activate();
            }
            onMiddleClicked: modelData.secondaryActivate()
            onRightClicked: if (modelData.hasMenu) menu.toggle()
            onScrolled: delta => modelData.scroll(delta, false)

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSize
                height: Theme.iconSize

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Theme.iconSize
                    source: button.modelData.icon
                    mipmap: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1
                        colorizationColor: Theme.text
                    }
                }
                Rectangle {
                    visible: button.attention
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

            TrayMenu {
                id: menu

                target: button
                handle: button.modelData.menu
            }
        }
    }

    // The item's DBus menu in the bar's popover style. Submenus replace the
    // list in place with a back row on top.
    component TrayMenu: Popover {
        id: pop

        property var handle: null
        // Submenu entries entered so far, outermost first.
        property var path: []
        readonly property var current: path.length > 0 ? path[path.length - 1] : handle

        onOpenChanged: if (!open) path = []

        QsMenuOpener {
            id: opener

            menu: pop.open ? pop.current : null
        }

        Column {
            spacing: 1
            width: 240

            ListRow {
                visible: pop.path.length > 0
                width: parent.width
                implicitHeight: 32
                icon: "arrow_back"
                iconColor: Theme.textMuted
                title: pop.path.length > 0 ? pop.current.text : ""
                onClicked: pop.path = pop.path.slice(0, -1)
            }
            Rectangle {
                visible: pop.path.length > 0
                width: parent.width
                height: 1
                color: Theme.hairline
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entry

                    required property var modelData
                    readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
                    readonly property bool checked: modelData.checkState === Qt.Checked

                    width: 240
                    height: modelData.isSeparator ? 9 : 32

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.hairline
                    }

                    ListRow {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        interactive: entry.modelData.enabled
                        opacity: entry.modelData.enabled ? 1 : 0.45
                        icon: entry.checkable ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? (entry.checked ? "radio_button_checked" : "radio_button_unchecked") : (entry.checked ? "check_box" : "check_box_outline_blank")) : ""
                        iconColor: entry.checked ? Theme.accent : Theme.textMuted
                        title: entry.modelData.text
                        trailingIcon: entry.modelData.hasChildren ? "chevron_right" : ""
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                pop.path = pop.path.concat([entry.modelData]);
                                return;
                            }
                            entry.modelData.triggered();
                            pop.open = false;
                        }
                    }
                }
            }

            Label {
                visible: opener.children.values.length === 0
                width: parent.width
                topPadding: 6
                bottomPadding: 6
                horizontalAlignment: Text.AlignHCenter
                text: "Empty menu"
                muted: true
                font.pixelSize: Theme.smallSize + 1
            }
        }
    }
}
