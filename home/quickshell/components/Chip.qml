import QtQuick
import qs.config

// Faint shared background for bar items that belong together (Wi-Fi,
// volume, battery). Grouping by surface instead of by extra spacing: the
// items keep their normal gaps, the cluster reads as one unit.
Rectangle {
    id: chip

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight - 8
    anchors.verticalCenter: parent?.verticalCenter
    radius: Theme.controlRadius
    color: Theme.alpha(Theme.text, 0.06)
    visible: row.implicitWidth > 0

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
    }
}
