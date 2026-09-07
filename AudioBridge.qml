import QtQuick
import Quickshell.Io

Item {
  id: root
  property bool bridgeEnabled: false
  property bool connected: false
  property real peak: 0
  property real rms: 0
  property bool vad: false
  signal frameReceived(real peak, real rms, bool vad, var timestamp)

  function reset() {
    connected = false
    peak = 0
    rms = 0
    vad = false
  }

  function parse(line) {
    const value = String(line || "").trim()
    if (!value) return
    try {
      const message = JSON.parse(value)
      if (message.status === "connected") { connected = true; return }
      if (message.status === "disconnected") { reset(); return }
      if (typeof message.peak !== "number" || typeof message.rms !== "number") return
      connected = true
      peak = Math.max(0, Math.min(1, message.peak))
      rms = Math.max(0, Math.min(1, message.rms))
      vad = !!message.vad
      frameReceived(peak, rms, vad, message.ts_ms || 0)
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
