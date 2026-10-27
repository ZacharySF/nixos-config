"""Publish the focused Niri application's name to every Ironbar bar.

Niri starts one copy of this per session (see niri/config.kdl). It follows
Niri's event stream and keeps the `focused_app` ironvar current; the bar's
center label module shows that variable on every monitor.

This is deliberately not an Ironbar `script` module in `watch` mode: Ironbar
0.19 tracks watched scripts by command string, so each additional monitor's
bar kills the previous bar's copy of the script and that bar's label goes blank.
"""

import json
import os
import select
import socket
import sys
import time


APP_NAMES = {
    "spotify": "Spotify",
    "com.spotify.client": "Spotify",
    "org.wezfurlong.wezterm": "WezTerm",
    "wezterm": "WezTerm",
    "foot": "Foot",
    "firefox": "Firefox",
    "org.mozilla.firefox": "Firefox",
    "chromium": "Chromium",
    "chromium-browser": "Chromium",
    "org.gnome.nautilus": "Files",
    "dev.zed.zed": "Zed",
    "code": "VS Code",
    "discord": "Discord",
    "obsidian": "Obsidian",
}

IRONVAR = "focused_app"
# Ironbar has no ironvars after a restart; look for a new instance this often.
RESYNC_SECONDS = 1


class FocusedApp:
    def __init__(self):
        self.windows = {}
        self.focused = None

    def update(self, event):
        if "WindowsChanged" in event:
            windows = event["WindowsChanged"]["windows"]
            self.windows = {w["id"]: w for w in windows}
            self.focused = next((w["id"] for w in windows if w["is_focused"]), None)
        elif "WindowOpenedOrChanged" in event:
            window = event["WindowOpenedOrChanged"]["window"]
            self.windows[window["id"]] = window
            if window["is_focused"]:
                self.focused = window["id"]
        elif "WindowFocusChanged" in event:
            self.focused = event["WindowFocusChanged"]["id"]
        elif "WindowClosed" in event:
            window_id = event["WindowClosed"]["id"]
            self.windows.pop(window_id, None)
            if self.focused == window_id:
                self.focused = None
        else:
            return None

        window = self.windows.get(self.focused)
        if window is None:
            return "Desktop"
        app_id = window.get("app_id") or ""
        name = APP_NAMES.get(app_id.lower())
        if not name:
            name = app_id.rsplit(".", 1)[-1] or window.get("title") or "Window"
            name = name[:1].upper() + name[1:]
        name = " ".join(name.split())
        if len(name) > 32:
            name = name[:31] + "…"
        # Ironbar escapes plain label text itself.
        return name


class IronbarVar:
    """Keeps one ironvar set, re-sending it when Ironbar restarts."""

    def __init__(self, key):
        self.key = key
        runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
        self.path = os.path.join(runtime_dir, "ironbar-ipc.sock")
        # (IPC socket identity, value) that Ironbar last accepted.
        self.synced = None

    def sync(self, value):
        if value is None:
            return
        try:
            st = os.stat(self.path)
        except OSError:
            return  # Ironbar is not running; retry on the next tick.
        wanted = ((st.st_ino, st.st_ctime_ns), value)
        if wanted == self.synced:
            return
        request = {"command": "var", "subcommand": "set", "key": self.key, "value": value}
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.settimeout(1)
                client.connect(self.path)
                client.sendall(json.dumps(request).encode() + b"\n")
                reply = b""
                while chunk := client.recv(4096):
                    reply += chunk
            if json.loads(reply)["type"] == "ok":
                self.synced = wanted
        except (OSError, ValueError, KeyError, TypeError):
            pass  # Ironbar is starting, stopping, or busy; retry on the next tick.


def follow_niri(niri_socket, ironbar):
    """Mirrors the focused app into Ironbar until Niri ends the event stream."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(niri_socket)
        client.sendall(b'"EventStream"\n')
        state = FocusedApp()
        label = None
        pending = b""
        while True:
            readable, _, _ = select.select([client], [], [], RESYNC_SECONDS)
            if readable:
                chunk = client.recv(65536)
                if not chunk:
                    return
                *lines, pending = (pending + chunk).split(b"\n")
                for line in lines:
                    update = state.update(json.loads(line))
                    if update is not None:
                        label = update
            ironbar.sync(label)


def main():
    niri_socket = os.environ.get("NIRI_SOCKET")
    if not niri_socket:
        sys.exit("ironbar-focused-app: NIRI_SOCKET is not set; start it from Niri")
    ironbar = IronbarVar(IRONVAR)
    while True:
        try:
            follow_niri(niri_socket, ironbar)
        except (FileNotFoundError, ConnectionRefusedError):
            return  # This Niri session is gone; the next one starts its own copy.
        except (OSError, KeyError, ValueError):
            pass
        # Reconnect if Niri's event connection is interrupted.
        time.sleep(1)


if __name__ == "__main__":
    main()
