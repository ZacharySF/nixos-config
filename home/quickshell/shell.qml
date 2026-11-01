//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.bar
import qs.config

// One bar per screen; mako remains the notification daemon.
ShellRoot {

    Variants {
        model: Quickshell.screens

        Bar {}
    }

}
