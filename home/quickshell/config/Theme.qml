pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Palette + shape tokens for every bar, popover and notification surface.
//
// Colors: skwd-wall renders ~/.local/state/skwd-theme/quickshell.json from
// the wallpaper palette (template in home/modules/skwd-wall/templates).
// Shape: Home Manager writes ~/.config/desktop-style/style.json from
// home/modules/style.nix. Both files are watched, so a palette apply or a
// switch restyles the running shell. The defaults below mirror the Mocha
// fallback and style.nix defaults so a missing file never breaks the bar.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // --- Palette -----------------------------------------------------------
    readonly property color background: pal.background
    readonly property color surface: pal.surface
    readonly property color surfaceLow: pal.surfaceLow
    readonly property color surfaceContainer: pal.surfaceContainer
    readonly property color surfaceHigh: pal.surfaceHigh
    readonly property color surfaceHighest: pal.surfaceHighest
    readonly property color text: pal.text
    readonly property color textMuted: pal.textMuted
    readonly property color outline: pal.outline
    readonly property color outlineVariant: pal.outlineVariant
    readonly property color accent: pal.accent
    readonly property color accentText: pal.accentText
    readonly property color accentContainer: pal.accentContainer
    readonly property color accentContainerText: pal.accentContainerText
    readonly property color secondary: pal.secondary
    readonly property color tertiary: pal.tertiary
    readonly property color error: pal.error
    readonly property color warning: pal.warning
    readonly property color success: pal.success
    readonly property color info: pal.info
    readonly property color magenta: pal.magenta
    readonly property color shadow: pal.shadow

    // Translucent surface used by islands, the strip and popovers.
    readonly property color panel: alpha(surfaceContainer, tok.surfaceOpacity)
    readonly property color panelSolid: surfaceContainer
    // Popovers and notification cards: near-opaque. At bar translucency the
    // backdrop (purple wallpaper above, dark window below) and the panel's
    // own drop shadow showed through as a two-tone wash.
    readonly property color popoverSurface: alpha(surfaceContainer, 0.97)
    readonly property color hover: alpha(text, 0.08)
    readonly property color pressed: alpha(text, 0.14)
    readonly property color hairline: alpha(outline, 0.55)

    // --- Shape -------------------------------------------------------------
    readonly property real radius: tok.cornerRadius
    readonly property real controlRadius: tok.controlRadius
    readonly property real outlineWidth: tok.outlineWidth
    readonly property real gap: tok.gaps
    readonly property real surfaceOpacity: tok.surfaceOpacity
    readonly property bool islands: tok.bar.layout !== "strip"
    // Tablet mode (set by shell.qml from the Convertible service) makes the
    // bar taller and every glyph and label larger for touch.
    property bool tablet: false
    readonly property real barHeight: tablet ? tok.bar.tabletHeight : tok.bar.height

    // Shadow under popovers and notifications (offset + soft blur).
    readonly property bool shadowEnabled: tok.shadow.enable
    readonly property real shadowBlur: tok.shadow.softness
    readonly property real shadowOffsetY: tok.shadow.offsetY
    readonly property real shadowOpacity: tok.shadow.opacity

    // --- Type --------------------------------------------------------------
    readonly property string font: tok.fonts.text
    readonly property string iconFont: tok.fonts.icons
    readonly property int textSize: tablet ? 14 : 12
    readonly property int smallSize: 10
    readonly property int titleSize: 14
    readonly property int iconSize: tablet ? 22 : 16

    // --- Motion ------------------------------------------------------------
    readonly property real motion: tok.animationScale
    readonly property int fast: Math.round(140 * motion)
    readonly property int medium: Math.round(240 * motion)
    readonly property int slow: Math.round(420 * motion)
    // Exponential ease-out: quick start, long settle.
    readonly property int easing: Easing.OutExpo

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    FileView {
        path: root.home + "/.local/state/skwd-theme/quickshell.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: pal

            property color background: "#11111b"
            property color surface: "#1e1e2e"
            property color surfaceLow: "#181825"
            property color surfaceContainer: "#1e1e2e"
            property color surfaceHigh: "#313244"
            property color surfaceHighest: "#45475a"
            property color text: "#cdd6f4"
            property color textMuted: "#a6adc8"
            property color outline: "#6c7086"
            property color outlineVariant: "#45475a"
            property color accent: "#cba6f7"
            property color accentText: "#1e1e2e"
            property color accentContainer: "#45475a"
            property color accentContainerText: "#cba6f7"
            property color secondary: "#b4befe"
            property color secondaryContainer: "#313244"
            property color secondaryContainerText: "#cdd6f4"
            property color tertiary: "#89b4fa"
            property color error: "#f38ba8"
            property color errorText: "#1e1e2e"
            property color warning: "#f9e2af"
            property color success: "#a6e3a1"
            property color info: "#94e2d5"
            property color magenta: "#f5c2e7"
            property color red: "#f38ba8"
            property color shadow: "#000000"
        }
    }

    FileView {
        path: root.home + "/.config/desktop-style/style.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: tok

            property real cornerRadius: 12
            property real controlRadius: 8
            property real outlineWidth: 0.5
            property real focusRingWidth: 1.5
            property real windowBorderWidth: 0
            property real gaps: 8
            property real surfaceOpacity: 0.72
            property real animationScale: 1.0

            property JsonObject shadow: JsonObject {
                property bool enable: true
                property real softness: 24
                property real offsetY: 6
                property real opacity: 0.35
            }

            property JsonObject bar: JsonObject {
                property real height: 34
                property real tabletHeight: 52
                property string layout: "islands"
            }

            property JsonObject fonts: JsonObject {
                property string text: "IoskeleyMono Nerd Font Mono"
                property string icons: "Material Symbols Rounded"
            }
        }
    }
}
