import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string focusedScreenName: Hyprland.focusedMonitor
    ? String(Hyprland.focusedMonitor.name || "") : ""
  readonly property var focusedScreen: {
    const screens = Quickshell.screens || []
    for (let i = 0; i < screens.length; ++i) {
      if (String(screens[i].name || "") === root.focusedScreenName) return screens[i]
    }
    return screens.length ? screens[0] : null
  }

  HudConfig { id: config }
  OmarchyPalette { id: palette }
  VoxtypeState { id: voxtype }
  AudioBridge {
    id: audio
    bridgeEnabled: voxtype.listening
  }

  StrandsSurface {
    daemonState: voxtype.daemonState
    suppressed: voxtype.osdSuppressed
    audio: audio
    config: config
    paletteSource: palette
    targetScreen: root.focusedScreen
  }
}
