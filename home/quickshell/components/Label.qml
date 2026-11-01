import QtQuick
import qs.config

Text {
    property bool muted: false
    property bool strong: false

    // Grayscale antialiasing: subpixel (LCD) rendering fringes glyphs with
    // color on translucent layer surfaces.
    renderType: Text.QtRendering
    color: muted ? Theme.textMuted : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.textSize
    font.weight: strong ? Font.DemiBold : Font.Medium
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }
}
