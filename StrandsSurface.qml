import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: panel

  property string daemonState: "idle"
  property bool suppressed: false
  property var audio: null
  property var config: null
  property var paletteSource: null
  property var targetScreen: null
  readonly property bool active: !suppressed && daemonState !== "" && daemonState !== "idle"
  readonly property bool listening: daemonState === "recording" || daemonState === "streaming"
  property real presence: active ? 1 : 0
  property real flow: 0
  property double lastVoiceAt: 0
  property real elapsed: 0
  property double lastTick: 0

  screen: targetScreen
  visible: active || presence > 0.001
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "voxtype-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  Behavior on presence {
    NumberAnimation {
      duration: panel.active ? 180 : 800
      easing.type: panel.active ? Easing.OutCubic : Easing.InOutSine
    }
  }

  onActiveChanged: {
    if (active) {
      lastTick = Date.now()
    }
  }

  onListeningChanged: lastVoiceAt = 0

  Timer {
    interval: 16
    repeat: true
    running: panel.active || panel.presence > 0.001 || panel.flow > 0.001
    onTriggered: {
      const now = Date.now()
      const dt = panel.lastTick > 0 ? Math.min(0.1, Math.max(0.001, (now - panel.lastTick) / 1000)) : 0.016
      panel.lastTick = now
      const cfg = panel.config ? panel.config.values : ({})
      if (panel.active) {
        const idleRate = cfg.idleMotion === undefined ? 0.32 : cfg.idleMotion
        panel.elapsed += dt * (idleRate + panel.flow * (1 - idleRate))
      }
      if (panel.listening && panel.audio && cfg.audioResponse !== false && panel.audio.vad)
        panel.lastVoiceAt = now
      const voiceHeld = panel.listening && panel.lastVoiceAt > 0
        && now - panel.lastVoiceAt < (cfg.voiceHangMs || 2000)
      const flowTarget = voiceHeld ? 1 : 0
      const flowTauMs = flowTarget > panel.flow
        ? (cfg.flowAttackMs || 420) : (cfg.flowReleaseMs || 620)
      const flowAmount = 1 - Math.exp(-dt * 1000 / flowTauMs)
      panel.flow += (flowTarget - panel.flow) * flowAmount
      if (!panel.active && panel.flow < 0.001) panel.flow = 0
    }
  }

  Item {
    id: viewport
    readonly property real requestedWidth: panel.config ? panel.config.values.width : 640
    readonly property real requestedHeight: panel.config ? panel.config.values.height : 480
    readonly property real verticalOverscan: 320
    readonly property real renderHeight: requestedHeight + verticalOverscan
    readonly property real fitScale: Math.min(1,
      Math.min((panel.width - 8) / Math.max(1, requestedWidth),
               (panel.height - 8) / Math.max(1, renderHeight)))
    width: requestedWidth * fitScale
    height: renderHeight * fitScale
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: (panel.config ? panel.config.values.bottomMargin : 24)
      - verticalOverscan * fitScale / 2
    opacity: panel.presence

    StrandsEffect {
      anchors.fill: parent
      config: panel.config
      paletteSource: panel.paletteSource
      flow: panel.flow
      elapsed: panel.elapsed
      contentResolution: Qt.size(viewport.requestedWidth * viewport.fitScale,
                                 viewport.requestedHeight * viewport.fitScale)
    }
  }
}
