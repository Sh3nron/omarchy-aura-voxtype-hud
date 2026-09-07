import QtQuick
import Quickshell.Io

Item {
  id: root
  property bool bridgeEnabled: false
  property bool vad: false

  function reset() {
    vad = false
  }

  function parse(line) {
    const value = String(line || "").trim()
    if (!value) return
    try {
      const message = JSON.parse(value)
      if (message.status === "connected") return
      if (message.status === "disconnected") { reset(); return }
      if (typeof message.vad !== "number" && typeof message.vad !== "boolean") return
      vad = !!message.vad
    } catch (error) {
      console.warn("aura-voxtype-hud: ignored malformed audio frame")
    }
  }

  onBridgeEnabledChanged: {
    retry.stop()
    bridge.running = bridgeEnabled
    if (!bridgeEnabled) reset()
  }

  Process {
    id: bridge
    command: ["/usr/bin/voxtype-audio-bridge"]
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => root.parse(data)
    }
    onRunningChanged: {
      if (!running) {
        root.reset()
        if (root.bridgeEnabled) retry.restart()
      }
    }
  }

  Timer {
    id: retry
    interval: 1000
    onTriggered: if (root.bridgeEnabled && !bridge.running) bridge.running = true
  }
}
