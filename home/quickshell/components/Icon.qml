import QtQuick
import qs.config

// Material Symbols Rounded glyph by ligature name ("wifi", "battery_5_bar").
// `fill` animates the FILL axis, so active states can swell from outline to
// solid instead of swapping glyphs.
Text {
    id: icon

    property string name
    property real fill: 0
    property real size: Theme.iconSize
    property int weight: 450

    // Match the GitHub icon's size without enlarging individual status glyphs.
    readonly property real optical: 1

    text: name
    // Vector glyph rendering: crisp at any size, no color fringes.
    renderType: Text.CurveRendering
    color: Theme.text
    font.family: Theme.iconFont
    font.pixelSize: Math.round(size * optical)
    // Optical size follows the drawn size, so at Theme.iconSize (20 → opsz
    // 20, 40 device px at scale 2) every grid unit is exactly 2 pixels and
    // strokes such as the plug's prongs land on whole pixels.
    font.variableAxes: ({
            "FILL": fill,
            "wght": weight,
            "GRAD": 0,
            "opsz": Math.max(20, Math.min(48, size))
        })
    // A whole-pixel box keeps the glyph from being centered on half pixels.
    width: Math.round(size)
    height: Math.round(size)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        NumberAnimation {
            duration: Theme.medium
            easing.type: Theme.easing
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }
}
