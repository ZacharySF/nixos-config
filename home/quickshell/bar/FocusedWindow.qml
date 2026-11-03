import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Focused window: app icon + short app name, a float badge for floating
// windows. Hover for title and geometry; middle-click closes; scrolling
// walks columns; right-click toggles floating.
BarButton {
    id: root

    readonly property var win: Niri.focusedWindow
    readonly property var entry: win ? DesktopEntries.heuristicLookup(win.app_id ?? "") : null
    readonly property string shortName: {
        if (!win)
            return "";
        const name = entry?.name ?? "";
        if (name !== "" && name.length <= 10)
            return name.toLowerCase();
        if (name !== "")
            return name.split(/\s+/)[0].toLowerCase();
        const id = (win.app_id ?? "").split(".").pop() || "window";
        return id.split("-")[0].toLowerCase();
    }
    readonly property string iconSource: {
        if (!win)
            return "";
        const candidates = [entry?.icon, win.app_id, (win.app_id ?? "").toLowerCase()];
        for (const c of candidates)
            if (c && Quickshell.hasThemeIcon(c))
                return Quickshell.iconPath(c);
        return "";
    }

    // Narrow (portrait) screens: icon only.
    property bool narrow: false

    visible: win !== null
    spacing: 7
    tooltip: {
        if (!win)
            return "";
        const lines = [win.title ?? ""];
        const where = win.is_floating ? "floating" : (win.layout?.pos_in_scrolling_layout ? `column ${win.layout.pos_in_scrolling_layout[0]}, tile ${win.layout.pos_in_scrolling_layout[1]}` : "");
        const size = win.layout ? `${win.layout.window_size[0]}×${win.layout.window_size[1]}` : "";
        lines.push([win.app_id, win.pid ? `pid ${win.pid}` : ""].filter(s => s).join(" · "));
        lines.push([where, size].filter(s => s).join(" · "));
        return lines.filter(s => s).join("\n");
    }

    onMiddleClicked: if (win) Niri.closeWindow(win.id)
    onRightClicked: if (win) Niri.action("ToggleWindowFloating", { id: win.id })
    onClicked: if (win) Niri.action("CenterWindow", { id: win.id })
    onScrolled: delta => delta > 0 ? Niri.focusColumnLeft() : Niri.focusColumnRight()

    Item {
        width: 18
        height: 18
        anchors.verticalCenter: parent.verticalCenter

        Image {
            id: appIcon

            anchors.fill: parent
            source: root.iconSource
            sourceSize.width: 36
            sourceSize.height: 36
            smooth: true
            mipmap: true
            visible: status === Image.Ready
        }

        // No themed icon: a tinted monogram tile.
        Rectangle {
            anchors.fill: parent
            visible: !appIcon.visible
            radius: 5
            color: Theme.alpha(Theme.accent, 0.25)

            Label {
                anchors.centerIn: parent
                text: root.shortName.charAt(0).toUpperCase()
                font.pixelSize: 11
                strong: true
                color: Theme.accent
            }
        }
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.narrow
        text: root.shortName
        width: Math.min(implicitWidth, 120)
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.win?.is_floating ?? false
        name: "picture_in_picture"
        size: 15
        color: Theme.secondary
    }
}
