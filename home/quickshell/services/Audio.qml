pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink/source plus device and stream lists from Pipewire. Every node
// listed here is bound through the tracker, so `audio` and `properties`
// stay live; nothing is polled.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Visual (cubic) volume, 0..1 at 100%; above 1 when over-amplified.
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: byLabel(nodes.filter(n => n.audio !== null && !n.isStream && n.isSink))
    readonly property var sources: byLabel(nodes.filter(n => n.audio !== null && !n.isStream && !n.isSink))
    readonly property var streams: nodes.filter(n => n.audio !== null && n.isStream)
    readonly property var playbackStreams: streams.filter(n => n.isSink && !ownStream(n))
    readonly property var captureStreams: streams.filter(n => !n.isSink && !ownStream(n))


    function byLabel(list) {
        return list.sort((a, b) => label(a).localeCompare(label(b)));
    }
    // Streams opened by this shell (peak monitors) are not the user's.
    function ownStream(node) {
        const props = node.properties ?? {};
        const pid = parseInt(props["application.process.id"] ?? "0");
        return pid === Quickshell.processId || /quickshell/i.test(props["application.name"] ?? "");
    }

    function label(node) {
        return node.nickname || node.description || node.name;
    }

    function streamName(node) {
        const props = node.properties ?? {};
        return props["application.name"] || props["node.name"] || node.description || node.name;
    }

    function streamIcon(node) {
        const props = node.properties ?? {};
        return props["application.icon-name"] || props["application.name"] || "";
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    PwObjectTracker {
        objects: root.sinks.concat(root.sources, root.streams)
    }
}
