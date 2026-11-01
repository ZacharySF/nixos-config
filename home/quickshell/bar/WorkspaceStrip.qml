import QtQuick
import Quickshell
import qs.config
import qs.services

// Workspaces of one output. Inactive workspaces are thin bars whose height
// grows with their column count; the active workspace expands into a live
// minimap of its columns, drawn to width, with the on-screen span bracketed.
//
// Clicks: a thin bar focuses that workspace, a tile focuses that window, and
// anywhere else on the active minimap toggles the overview.
Item {
    id: strip

    required property string output
    required property real outputWidth

    // Minimap scale: one screen width of columns maps to this many pixels.
    readonly property real screenSpan: 60
    readonly property real mapHeight: 18
    readonly property real scale: screenSpan / Math.max(1, outputWidth)

    // No windows on any workspace of this output (stash aside): nothing to
    // map, so take no room and the island around the launcher is a square.
    readonly property bool hasWindows: Niri.workspacesOn(output).some(w => Niri.windowsOn(w.id).length > 0)
    visible: hasWindows && row.implicitWidth > 0
    implicitWidth: visible ? row.implicitWidth + 4 : 0
    implicitHeight: Theme.barHeight - 8

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: ScriptModel {
                // niri always keeps one empty workspace last; it carries no
                // information unless it is the one you are on.
                values: {
                    const list = Niri.workspacesOn(strip.output);
                    const last = list[list.length - 1];
                    if (last && !last.is_active && Niri.windowsOn(last.id).length === 0)
                        list.pop();
                    return list;
                }
                objectProp: "id"
            }

            delegate: Item {
                id: ws

                required property var modelData
                readonly property bool active: modelData.is_active
                readonly property var columns: Niri.columnsOn(modelData.id)
                readonly property var floating: Niri.floatingOn(modelData.id)
                readonly property real gapPx: 2
                readonly property var widths: columns.map(c => Math.max(5, c.width * strip.scale))
                readonly property real mapWidth: columns.length === 0 ? 16 : widths.reduce((a, b) => a + b, 0) + gapPx * (columns.length - 1)
                readonly property var span: visibleSpan()

                // Estimated on-screen columns as [firstIndex, lastIndex] into
                // `columns`. niri reports tile positions in the workspace view
                // when it has them; otherwise fit a screen width around the
                // active column.
                function visibleSpan() {
                    const n = columns.length;
                    if (n === 0)
                        return [0, -1];
                    const reported = columns.map(c => c.tiles[0].layout.tile_pos_in_workspace_view);
                    if (reported.some(p => p)) {
                        let first = -1, last = -1;
                        reported.forEach((p, i) => {
                            if (p && p[0] + columns[i].width > 0 && p[0] < strip.outputWidth) {
                                if (first < 0)
                                    first = i;
                                last = i;
                            }
                        });
                        if (first >= 0)
                            return [first, last];
                    }
                    let focus = columns.findIndex(c => c.tiles.some(t => t.id === modelData.active_window_id));
                    if (focus < 0)
                        focus = 0;
                    let used = columns[focus].width, first = focus, last = focus;
                    while (last + 1 < n && used + columns[last + 1].width <= strip.outputWidth + 1)
                        used += columns[++last].width;
                    while (first > 0 && used + columns[first - 1].width <= strip.outputWidth + 1)
                        used += columns[--first].width;
                    return [first, last];
                }

                function xOf(i) {
                    let x = 0;
                    for (let k = 0; k < i; k++)
                        x += widths[k] + gapPx;
                    return x;
                }

                implicitWidth: active ? mapWidth + 8 : 5
                implicitHeight: strip.implicitHeight

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Theme.medium
                        easing.type: Theme.easing
                    }
                }

                // Inactive: a thin bar, taller with more columns.
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: ws.columns.length === 0 ? 4 : Math.min(strip.mapHeight, 6 + ws.columns.length * 3)
                    radius: 2
                    opacity: ws.active ? 0 : 1
                    visible: opacity > 0
                    color: ws.modelData.is_urgent ? Theme.error : barMouse.containsMouse ? Theme.text : Theme.alpha(Theme.text, ws.columns.length === 0 ? 0.28 : 0.5)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                    Behavior on height {
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

                MouseArea {
                    id: barMouse

                    anchors.fill: parent
                    anchors.margins: -2
                    enabled: !ws.active
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(ws.modelData.id)
                }

                // Active: the minimap.
                Item {
                    id: map

                    anchors.centerIn: parent
                    width: ws.mapWidth
                    height: strip.mapHeight
                    opacity: ws.active ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.medium
                        }
                    }

                    // One input layer over the whole minimap (z above the
                    // tiles). Press and drag sideways: the column under the
                    // pointer gets focus as you pass it, so niri scrolls the
                    // view along. A press without a drag focuses the tile
                    // under it, or opens the overview from the gaps.
                    MouseArea {
                        id: mapInput

                        property real pressX: 0
                        property bool dragging: false
                        property int lastColumn: -1

                        // Column index under a map x, clamped to the ends.
                        function columnAt(x) {
                            const n = ws.columns.length;
                            for (let i = 0; i < n; i++)
                                if (x < ws.xOf(i) + ws.widths[i] + ws.gapPx / 2)
                                    return i;
                            return n - 1;
                        }
                        function tileAt(x, y) {
                            const i = columnAt(x);
                            if (i < 0 || x < ws.xOf(i) || x > ws.xOf(i) + ws.widths[i])
                                return null;
                            const col = ws.columns[i];
                            const total = col.tiles.reduce((a, t) => a + t.layout.tile_size[1], 0);
                            let top = 0;
                            for (const t of col.tiles) {
                                top += t.layout.tile_size[1] / Math.max(1, total) * map.height;
                                if (y <= top)
                                    return t;
                            }
                            return col.tiles[col.tiles.length - 1];
                        }
                        function focusColumn(i) {
                            if (i < 0 || i === lastColumn)
                                return;
                            lastColumn = i;
                            const col = ws.columns[i];
                            // Keep the window last active in that column.
                            const tile = col.tiles.find(t => t.id === ws.modelData.active_window_id) ?? col.tiles[0];
                            Niri.focusWindow(tile.id);
                        }

                        z: 10
                        anchors.fill: parent
                        anchors.margins: -4
                        preventStealing: true
                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        onPressed: m => {
                            pressX = m.x;
                            dragging = false;
                            lastColumn = -1;
                        }
                        onPositionChanged: m => {
                            if (!pressed || ws.columns.length === 0)
                                return;
                            if (!dragging && Math.abs(m.x - pressX) < 4)
                                return;
                            dragging = true;
                            focusColumn(columnAt(m.x - 4));
                        }
                        onReleased: m => {
                            if (dragging) {
                                dragging = false;
                                return;
                            }
                            const tile = tileAt(m.x - 4, m.y - 4);
                            if (tile)
                                Niri.focusWindow(tile.id);
                            else
                                Niri.toggleOverview();
                        }
                    }

                    // Empty workspace: a dashed-looking ghost slot.
                    Rectangle {
                        anchors.fill: parent
                        visible: ws.columns.length === 0
                        radius: 3
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.3)
                    }

                    Repeater {
                        model: ScriptModel {
                            values: ws.columns
                            objectProp: "index"
                        }

                        delegate: Item {
                            id: col

                            required property var modelData
                            required property int index
                            readonly property real total: modelData.tiles.reduce((a, t) => a + t.layout.tile_size[1], 0)

                            x: ws.xOf(index)
                            width: ws.widths[index] ?? 5
                            height: map.height

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.medium
                                    easing.type: Theme.easing
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.medium
                                    easing.type: Theme.easing
                                }
                            }

                            Column {
                                anchors.fill: parent
                                spacing: 2

                                Repeater {
                                    model: col.modelData.tiles

                                    delegate: Rectangle {
                                        id: tile

                                        required property var modelData
                                        readonly property bool focused: modelData.is_focused

                                        width: col.width
                                        height: Math.max(3, (col.height - 2 * (col.modelData.tiles.length - 1)) * modelData.layout.tile_size[1] / Math.max(1, col.total))
                                        radius: 2.5
                                        color: focused ? Theme.alpha(Theme.accent, 0.4) : tileMouse.containsMouse ? Theme.alpha(Theme.text, 0.18) : "transparent"
                                        border.width: 1
                                        border.color: focused ? Theme.accent : modelData.is_urgent ? Theme.error : Theme.alpha(Theme.text, 0.55)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Theme.fast
                                            }
                                        }

                                        MouseArea {
                                            id: tileMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Floating windows: short ticks riding above the columns.
                    Row {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Repeater {
                            model: ws.floating

                            delegate: Rectangle {
                                required property var modelData

                                width: 8
                                height: 3
                                radius: 1.5
                                color: modelData.is_focused ? Theme.accent : Theme.alpha(Theme.text, 0.6)
                            }
                        }
                    }

                    // On-screen bracket.
                    Item {
                        visible: ws.columns.length > 1 && ws.span[1] >= ws.span[0]
                        x: ws.xOf(ws.span[0]) - 3
                        width: ws.xOf(ws.span[1]) + (ws.widths[ws.span[1]] ?? 0) - ws.xOf(ws.span[0]) + 6
                        height: parent.height + 6
                        y: -3

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.medium
                                easing.type: Theme.easing
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.medium
                                easing.type: Theme.easing
                            }
                        }

                        Repeater {
                            model: 2

                            delegate: Item {
                                required property int index

                                x: index === 0 ? 0 : parent.width - width
                                width: 3
                                height: parent.height

                                Rectangle {
                                    width: 1
                                    height: parent.height
                                    x: index === 0 ? 0 : 2
                                    color: Theme.accent
                                }
                                Rectangle {
                                    width: 3
                                    height: 1
                                    color: Theme.accent
                                }
                                Rectangle {
                                    width: 3
                                    height: 1
                                    y: parent.height - 1
                                    color: Theme.accent
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
