import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  QtObject {
    id: previewConfig
    property var values: ({
      paletteMode: "original",
      colors: ["#F97316", "#7C3AED", "#06B6D4"],
      count: 3, speed: 0.5, amplitude: 1.0, waviness: 1.0,
      thickness: 0.7, glow: 2.6, taper: 3.0, spread: 1.0,
      hueShift: 0.0, intensity: 0.6, saturation: 2.0,
      opacity: 1.0, scale: 1.5, glass: false
    })
  }

  PanelWindow {
    anchors { top: true; right: true; bottom: true; left: true }
    color: "#08070d"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    StrandsEffect {
      id: effect
      width: 960
      height: 540
      anchors.centerIn: parent
      config: previewConfig
      flow: 1
    }

    Timer {
      interval: 16
      repeat: true
      running: true
      onTriggered: effect.elapsed += interval / 1000
    }

    Timer {
      interval: 3000
      running: true
      onTriggered: Qt.quit()
    }
  }
}
