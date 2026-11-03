import QtQuick
import qs.components

BarButton {
    readonly property url url: "https://github.com/zacharysf"
    tooltip: "GitHub · ZacharySF"
    onClicked: Qt.openUrlExternally(url)

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf09b"
        font.pixelSize: 16
    }
}
