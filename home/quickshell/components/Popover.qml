import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config

// Panel that drops below a bar item.
//
// It is a full-screen transparent overlay rather than an xdg_popup: a popup
// can only take its dismiss-on-outside-click grab from a recent pointer or
// keyboard event on the bar itself, so touch taps and keybind/IPC opens left
// it stuck open. The overlay catches the first press outside the panel
// (mouse or touch) and closes, and holds the keyboard so Escape works. The
// press that closes it is consumed, as a popup grab would.
PanelWindow {
    id: pop

    required property Item target
    default property alias content: body.data
    property real padding: 14
    property bool open: false

    // Bar window holding the target, and the target's place in it, taken
    // when opening (the bar does not move while a panel is open).
    readonly property var barWindow: target.QsWindow.window
    property point anchorPoint: Qt.point(0, 0)

    function toggle() {
        open = !open;
    }

    onOpenChanged: {
        if (!open)
            return;
        anchorPoint = barWindow ? barWindow.itemPosition(target) : Qt.point(0, 0);
        enter.restart();
    }

    screen: barWindow?.screen ?? null
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: Config.namespace + "-popover"
    WlrLayershell.layer: WlrLayer.Overlay
    // On-demand, not exclusive: an exclusive grab would also lock out
    // keyboard input to everything else while a panel is open.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Outside the panel: any press closes it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: pop.open = false
    }

    Rectangle {
        id: frame

        readonly property real barTop: Config.dev ? pop.height - (pop.barWindow?.height ?? 0) - Config.devOffset : 0
        readonly property real centerX: pop.anchorPoint.x + pop.target.width / 2

        x: Math.round(Math.max(Theme.gap, Math.min(pop.width - width - Theme.gap, centerX - width / 2)))
        y: Math.round(Config.dev ? barTop + pop.anchorPoint.y - Theme.gap - height : barTop + pop.anchorPoint.y + pop.target.height + Theme.gap + 2)
        implicitWidth: body.implicitWidth + pop.padding * 2
        implicitHeight: body.implicitHeight + pop.padding * 2
        width: implicitWidth
        height: implicitHeight
        radius: Theme.radius
        color: Theme.popoverSurface

        layer.enabled: Theme.shadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.shadow, Theme.shadowOpacity)
            shadowBlur: 1.0
            blurMax: Math.round(Theme.shadowBlur)
            shadowVerticalOffset: Theme.shadowOffsetY
            shadowHorizontalOffset: 0
        }

        transform: Translate {
            id: slide
        }

        // Presses on the panel's own background must not reach the scrim.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Outline {}

        Item {
            id: body

            x: pop.padding
            y: pop.padding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            focus: true
            Keys.onEscapePressed: pop.open = false
        }
    }

    ParallelAnimation {
        id: enter

        NumberAnimation {
            target: frame
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.fast
        }
        NumberAnimation {
            target: slide
            property: "y"
            from: Config.dev ? 6 : -6
            to: 0
            duration: Theme.medium
            easing.type: Theme.easing
        }
    }
}
