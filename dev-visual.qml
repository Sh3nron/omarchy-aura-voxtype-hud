import QtQuick
import Quickshell

ShellRoot {
  HudConfig { id: config }
  OmarchyPalette { id: palette }
  StrandsSurface {
    daemonState: "recording"
    config: config
    paletteSource: palette
    targetScreen: Quickshell.screens.length ? Quickshell.screens[0] : null
  }
  Timer {
    interval: 2500
    running: true
    onTriggered: Qt.quit()
  }
}
