import QtQuick
import QtQuick.Shapes
import qs.config

// Hairline outline for rounded surfaces. Rectangle.border renders a
// one-physical-pixel stroke unevenly around the corner arcs (thin and faded
// on the curve, solid on the straights); the curve renderer antialiases the
// whole path analytically so the line keeps one weight all the way round.
// Fill the parent; draw the surface itself with a borderless Rectangle.
Shape {
    id: outline

    property real radius: Theme.radius
    property real strokeWidth: Theme.outlineWidth
    property color strokeColor: Theme.hairline

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    visible: strokeWidth > 0

    ShapePath {
        strokeWidth: outline.strokeWidth
        strokeColor: outline.strokeColor
        fillColor: "transparent"

        PathRectangle {
            x: outline.strokeWidth / 2
            y: outline.strokeWidth / 2
            width: outline.width - outline.strokeWidth
            height: outline.height - outline.strokeWidth
            radius: Math.max(0, outline.radius - outline.strokeWidth / 2)
        }
    }
}
