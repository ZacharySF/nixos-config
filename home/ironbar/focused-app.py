"""Stream the focused Niri application's name to Ironbar's watch module."""

import html
import json
import os
import socket
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
    "org.gnome.nautilus": "Files",
    "dev.zed.zed": "Zed",
    "code": "VS Code",
    "discord": "Discord",
    "obsidian": "Obsidian",
}


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
        return html.escape(name)


def main():
    previous = None
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.connect(os.environ["NIRI_SOCKET"])
                client.sendall(b'"EventStream"\n')
                state = FocusedApp()
                with client.makefile("r", encoding="utf-8") as events:
                    for line in events:
                        label = state.update(json.loads(line))
                        if label is not None and label != previous:
                            print(label, flush=True)
                            previous = label
        except (OSError, KeyError, ValueError):
            pass
        # Reconnect if Niri's event connection is interrupted.
        time.sleep(1)


if __name__ == "__main__":
    main()
