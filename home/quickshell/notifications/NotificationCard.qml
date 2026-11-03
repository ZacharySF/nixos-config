import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.config
import qs.services

// One notification. Used by the popups (with a timeout bar, actions and
// inline reply) and, with `compact`, by the notification center.
Rectangle {
    id: card

    required property var entry
    property bool compact: false
    // Popup timeout in ms; 0 = sticky. The bar shrinks and pauses on hover.
    property int timeout: 0
    readonly property bool hovered: hover.hovered
    readonly property bool critical: entry.urgency === 2
    property real now: Date.now()

    signal timedOut

    // Resolved app icon; falls back to the notification image when the app
    // has no icon of its own (notify-send -i, browsers), which then is not
    // repeated as a thumbnail.
    readonly property string appIconSource: iconSource(entry)
    readonly property bool imageIsIcon: appIconSource === "" && (entry.image ?? "") !== ""

    function iconSource(e) {
        const c = e.appIcon || "";
        if (c.startsWith("/"))
            return "file://" + c;
        if (c.includes("://"))
            return c;
        if (c && Quickshell.hasThemeIcon(c))
            return Quickshell.iconPath(c);
        const de = DesktopEntries.heuristicLookup(e.desktopEntry || e.appName || "");
        return de?.icon && Quickshell.hasThemeIcon(de.icon) ? Quickshell.iconPath(de.icon) : "";
    }

    function ago(t) {
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Qt.formatDate(new Date(t), "ddd");
    }

    implicitWidth: 360
    implicitHeight: layout.implicitHeight + (compact ? 20 : 26)
    radius: compact ? Theme.controlRadius + 2 : Theme.radius
    color: compact ? (hover.hovered ? Theme.alpha(Theme.text, 0.09) : Theme.alpha(Theme.text, 0.05)) : Theme.popoverSurface

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Outline {
        visible: !card.compact
        strokeColor: card.critical ? Theme.error : Theme.hairline
    }

    HoverHandler {
        id: hover
    }

    Timer {
        interval: 30000
        running: card.visible
        repeat: true
        onTriggered: card.now = Date.now()
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: Notifications.activate(card.entry.key)
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: Notifications.dismiss(card.entry.key)
    }

    Column {
        id: layout

        x: 14
        y: card.compact ? 10 : 13
        width: card.width - 28
        spacing: 8

        Row {
            width: parent.width
            spacing: 12

            // App icon, or a tinted monogram.
            Item {
                width: card.compact ? 28 : 34
                height: width

                Image {
                    id: appIcon

                    anchors.fill: parent
                    source: card.imageIsIcon ? card.entry.image : card.appIconSource
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !appIcon.visible
                    radius: Theme.controlRadius
                    color: Theme.alpha(card.critical ? Theme.error : Theme.accent, 0.22)

                    Icon {
                        anchors.centerIn: parent
                        name: card.critical ? "priority_high" : "notifications"
                        fill: 1
                        size: 18
                        color: card.critical ? Theme.error : Theme.accent
                    }
                }
            }

            Column {
                width: parent.width - (card.compact ? 28 : 34) - 12 - (thumb.visible ? thumb.width + 12 : 0)
                spacing: 3

                Item {
                    visible: !card.compact
                    width: parent.width
                    height: appLine.implicitHeight

                    Label {
                        id: appLine

                        width: parent.width - when.implicitWidth - 30
                        text: card.entry.appName || "Notification"
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                    Label {
                        id: when

                        anchors.right: parent.right
                        anchors.rightMargin: closeBtn.visible ? 24 : 0
                        text: card.ago(card.entry.time)
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                }
                Item {
                    width: parent.width
                    height: summary.implicitHeight

                    Label {
                        id: summary

                        width: parent.width - (card.compact ? compactWhen.implicitWidth + 30 : 0)
                        text: card.entry.summary
                        strong: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Label {
                        id: compactWhen

                        visible: card.compact
                        anchors.right: parent.right
                        anchors.rightMargin: closeBtn.visible ? 24 : 0
                        y: 1
                        text: card.ago(card.entry.time)
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: card.entry.body
                    color: Theme.textMuted
                    font.weight: Font.Normal
                    wrapMode: Text.Wrap
                    maximumLineCount: card.compact ? 2 : 4
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    onLinkActivated: url => Qt.openUrlExternally(url)
                    lineHeight: 1.1
                }
            }

            Rectangle {
                id: thumb

                visible: !card.imageIsIcon && (card.entry.image ?? "") !== "" && thumbImg.status === Image.Ready
                width: 52
                height: 52
                radius: Theme.controlRadius
                color: "transparent"
                clip: true

                Image {
                    id: thumbImg

                    anchors.fill: parent
                    source: card.entry.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 104
                    sourceSize.height: 104
                    smooth: true
                }
            }
        }

        // Action buttons (not for history entries whose sender is gone).
        Flow {
            width: parent.width
            spacing: 6
            visible: !card.compact && card.entry.live && actionsRep.count > 0

            Repeater {
                id: actionsRep

                model: (card.entry.actions ?? []).filter(a => a.identifier !== "default" && a.text !== "")

                delegate: Rectangle {
                    id: act

                    required property var modelData

                    width: Math.min(actLabel.implicitWidth + 24, layout.width)
                    height: 30
                    radius: Theme.controlRadius
                    color: actMouse.containsMouse ? Theme.alpha(Theme.accent, 0.28) : Theme.alpha(Theme.text, 0.08)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Label {
                        id: actLabel

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, layout.width - 24)
                        text: act.modelData.text
                        font.pixelSize: Theme.smallSize + 1
                        strong: true
                    }
                    MouseArea {
                        id: actMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.invokeAction(card.entry.key, act.modelData.identifier)
                    }
                }
            }
        }

        // Inline reply (messaging apps).
        Rectangle {
            width: parent.width
            height: 34
            visible: !card.compact && card.entry.live && (card.entry.notif?.hasInlineReply ?? false)
            radius: Theme.controlRadius
            color: Theme.alpha(Theme.text, 0.07)
            border.width: replyField.activeFocus ? 1 : 0
            border.color: Theme.accent

            TextField {
                id: replyField

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 36
                background: null
                color: Theme.text
                placeholderText: card.entry.notif?.inlineReplyPlaceholder || "Reply"
                placeholderTextColor: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: Theme.textSize
                selectionColor: Theme.alpha(Theme.accent, 0.4)
                verticalAlignment: TextInput.AlignVCenter
                onAccepted: {
                    if (text !== "")
                        Notifications.reply(card.entry.key, text);
                }
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                name: "send"
                size: 17
                color: replyField.text !== "" ? Theme.accent : Theme.textMuted

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (replyField.text !== "") Notifications.reply(card.entry.key, replyField.text)
                }
            }
        }
    }

    // Close, shown on hover.
    Rectangle {
        id: closeBtn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 22
        height: 22
        radius: 11
        visible: hover.hovered
        color: closeMouse.containsMouse ? Theme.alpha(Theme.text, 0.16) : Theme.alpha(Theme.text, 0.08)

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 14
        }
        MouseArea {
            id: closeMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifications.dismiss(card.entry.key)
        }
    }

    // Remaining time; pauses while hovered.
    Rectangle {
        id: timeBar

        visible: card.timeout > 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        x: card.radius
        height: 2
        radius: 1
        width: (card.width - card.radius * 2) * progress
        color: Theme.alpha(card.critical ? Theme.error : Theme.accent, 0.6)

        property real progress: 1

        NumberAnimation on progress {
            id: countdown

            running: card.timeout > 0
            paused: running && card.hovered
            from: 1
            to: 0
            duration: card.timeout
            onFinished: card.timedOut()
        }
    }
}
