import QtQuick
import qs.config

// Horizontal value slider (0..1) with a leading icon inside the track.
// Drag, click, or scroll to change; `moved(value)` fires on user input only.
Item {
    id: slider

    property real value: 0
    property string icon: ""
    property color fillColor: Theme.accent
    property real step: 0.05

    signal moved(real value)

    implicitWidth: 260
    implicitHeight: 34

    function set(v) {
        const clamped = Math.max(0, Math.min(1, v));
        slider.moved(clamped);
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: Theme.controlRadius + 2
        color: Theme.alpha(Theme.text, 0.08)
        opacity: slider.enabled ? 1 : 0.45
        clip: true

        Rectangle {
            width: Math.max(height, track.width * Math.max(0, Math.min(1, slider.value)))
            height: parent.height
            radius: parent.radius
            color: slider.fillColor

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Theme.easing
                }
            }
        }

        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: slider.icon !== ""
            name: slider.icon
            size: 18
            fill: 1
            color: Theme.accentText
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        enabled: slider.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: m => slider.set(m.x / width)
        onPositionChanged: m => {
            if (pressed)
                slider.set(m.x / width);
        }
        onWheel: w => slider.set(slider.value + (w.angleDelta.y > 0 ? slider.step : -slider.step))
    }
}
