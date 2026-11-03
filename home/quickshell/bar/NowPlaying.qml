import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services

// The player Media picked: note icon, "Artist · Title" (scrolls on hover
// when cut), a hairline progress underline. Hidden when nothing qualifies
// or the player's own window is focused. Click toggles playback, scroll
// skips tracks, middle-click opens the panel.
BarButton {
    id: root

    readonly property MprisPlayer player: Media.player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string line: player ? [player.trackArtist, player.trackTitle].filter(s => s !== "").join(" · ") : ""
    readonly property bool hasProgress: player !== null && player.lengthSupported && player.positionSupported && player.length > 0
    readonly property real progress: hasProgress ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    // Set by the bar on narrow (portrait) screens, where there is no room.
    property bool narrow: false

    visible: !narrow && player !== null && (!Media.focused || pop.open)
    active: pop.open
    tooltip: player ? [player.trackTitle, player.trackArtist, player.trackAlbum, player.identity].filter(s => s !== "").join("\n") : ""
    onClicked: if (player?.canTogglePlaying) player.togglePlaying()
    onMiddleClicked: pop.toggle()
    onRightClicked: pop.toggle()
    onScrolled: delta => {
        if (!player)
            return;
        if (delta > 0 && player.canGoPrevious)
            player.previous();
        else if (delta < 0 && player.canGoNext)
            player.next();
    }
    onPlayerChanged: if (!player) pop.open = false

    function clock(seconds) {
        const s = Math.max(0, Math.round(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    function shortName(entry) {
        const p = entry.player;
        const name = DesktopEntries.heuristicLookup(p.desktopEntry || p.identity)?.name ?? p.identity;
        return name.length > 12 ? name.split(/\s+/)[0] : name;
    }

    // MPRIS only pushes position on seeks; ask for it once a second while it moves.
    Timer {
        running: root.playing && root.hasProgress && (root.visible || pop.open)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "music_note"
    }

    Item {
        id: viewport

        readonly property real overflow: Math.max(0, title.implicitWidth - width)
        readonly property bool scrolling: root.hovered && overflow > 0

        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(title.implicitWidth, Math.round(metrics.averageCharacterWidth * 22))
        height: title.implicitHeight
        clip: true

        FontMetrics {
            id: metrics

            font: title.font
        }

        Label {
            id: title

            width: viewport.scrolling ? implicitWidth : viewport.width
            elide: viewport.scrolling ? Text.ElideNone : Text.ElideRight
            text: root.line
        }

        SequentialAnimation {
            running: viewport.scrolling
            loops: Animation.Infinite
            onRunningChanged: if (!running) title.x = 0

            PauseAnimation {
                duration: 700
            }
            NumberAnimation {
                target: title
                property: "x"
                to: -viewport.overflow
                duration: Math.max(400, viewport.overflow * 28)
            }
            PauseAnimation {
                duration: 1200
            }
            NumberAnimation {
                target: title
                property: "x"
                to: 0
                duration: Theme.slow
                easing.type: Theme.easing
            }
        }
    }

    Rectangle {
        parent: root
        visible: root.hasProgress
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.bottomMargin: 1
        height: 2
        radius: 1
        color: Theme.alpha(Theme.text, 0.1)

        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            Behavior on width {
                NumberAnimation {
                    duration: Theme.medium
                    easing.type: Theme.easing
                }
            }
        }
    }

    Popover {
        id: pop

        target: root

        Column {
            width: 320
            spacing: 10

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    id: artBox

                    width: 72
                    height: 72
                    radius: Theme.controlRadius + 2
                    color: Theme.alpha(Theme.text, 0.07)

                    Image {
                        id: art

                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        sourceSize.width: 144
                        sourceSize.height: 144
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: false
                    }
                    Item {
                        id: artMask

                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: artBox.radius
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: art.status === Image.Ready
                        source: art
                        maskEnabled: true
                        maskSource: artMask
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        name: "album"
                        size: 30
                        color: Theme.textMuted
                    }
                }

                Column {
                    width: parent.width - artBox.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Label {
                        width: parent.width
                        text: root.player?.trackTitle ?? ""
                        strong: true
                        font.pixelSize: Theme.titleSize
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.player?.trackArtist ?? ""
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: root.player?.trackAlbum ?? ""
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                }
            }

            Column {
                width: parent.width
                visible: root.hasProgress
                spacing: 2

                Slider {
                    width: parent.width
                    height: 14
                    enabled: root.player?.canSeek ?? false
                    fillColor: Theme.accent
                    step: 0.02
                    value: root.progress
                    onMoved: v => root.player.position = v * root.player.length
                }
                Item {
                    width: parent.width
                    height: 16

                    Label {
                        anchors.left: parent.left
                        text: root.player ? root.clock(root.player.position) : ""
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                    Label {
                        anchors.right: parent.right
                        text: root.player ? root.clock(root.player.length) : ""
                        muted: true
                        font.pixelSize: Theme.smallSize
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                BarButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 36
                    implicitHeight: 36
                    interactive: root.player?.canGoPrevious ?? false
                    opacity: interactive ? 1 : 0.35
                    onClicked: if (interactive) root.player.previous()

                    Icon {
                        name: "skip_previous"
                        size: 24
                        fill: 1
                    }
                }
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: playMouse.pressed ? Theme.mix(Theme.accent, Theme.text, 0.15) : Theme.accent

                    Icon {
                        anchors.centerIn: parent
                        name: root.playing ? "pause" : "play_arrow"
                        size: 26
                        fill: 1
                        color: Theme.accentText
                    }
                    MouseArea {
                        id: playMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
                    }
                }
                BarButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 36
                    implicitHeight: 36
                    interactive: root.player?.canGoNext ?? false
                    opacity: interactive ? 1 : 0.35
                    onClicked: if (interactive) root.player.next()

                    Icon {
                        name: "skip_next"
                        size: 24
                        fill: 1
                    }
                }
            }

            Segmented {
                width: parent.width
                visible: Media.eligible.length > 1
                options: Media.eligible.map(e => ({
                            value: e,
                            label: root.shortName(e)
                        }))
                current: Media.active
                onSelected: v => Media.choose(v)
            }
        }
    }
}
