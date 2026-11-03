import QtQuick
import Quickshell
import qs.components
import qs.config

// Time and date; click for a month calendar.
BarButton {
    id: root

    active: pop.open
    spacing: 8
    onClicked: {
        cal.shown = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
        pop.toggle();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(clock.date, "h:mm AP")
        strong: true
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDate(clock.date, "ddd d")
        muted: true
    }

    Popover {
        id: pop

        target: root

        Column {
            id: cal

            property date shown: new Date()
            readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
            readonly property var cells: {
                const y = shown.getFullYear(), m = shown.getMonth();
                const lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
                const out = [];
                for (let i = 0; i < 42; i++)
                    out.push(new Date(y, m, 1 - lead + i));
                return out;
            }

            spacing: 10
            width: 7 * 34

            Item {
                width: parent.width
                height: 28

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(cal.shown, "MMMM yyyy")
                    strong: true
                    font.pixelSize: Theme.titleSize
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    BarButton {
                        implicitHeight: 28
                        onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() - 1, 1)

                        Icon {
                            name: "chevron_left"
                        }
                    }
                    BarButton {
                        implicitHeight: 28
                        onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 1)

                        Icon {
                            name: "chevron_right"
                        }
                    }
                }
            }

            Grid {
                columns: 7

                Repeater {
                    model: 7

                    delegate: Label {
                        required property int index

                        width: 34
                        height: 22
                        horizontalAlignment: Text.AlignHCenter
                        muted: true
                        font.pixelSize: Theme.smallSize
                        text: Qt.locale().dayName((cal.firstDay + index) % 7, Locale.NarrowFormat)
                    }
                }

                Repeater {
                    model: cal.cells

                    delegate: Item {
                        id: cell

                        required property var modelData
                        readonly property bool today: modelData.toDateString() === clock.date.toDateString()
                        readonly property bool inMonth: modelData.getMonth() === cal.shown.getMonth()

                        width: 34
                        height: 30

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            color: cell.today ? Theme.accent : "transparent"
                        }
                        Label {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.today ? Theme.accentText : cell.inMonth ? Theme.text : Theme.alpha(Theme.textMuted, 0.5)
                            strong: cell.today
                        }
                    }
                }
            }
        }
    }
}
