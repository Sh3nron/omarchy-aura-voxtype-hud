import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))
  property string daemonState: "idle"
  property bool osdSuppressed: false
  readonly property bool active: daemonState !== "" && daemonState !== "idle"
  readonly property bool listening: daemonState === "recording" || daemonState === "streaming"

  function loadState(text) {
    const value = String(text || "idle").trim()
    daemonState = ["recording", "streaming", "transcribing"].indexOf(value) >= 0 ? value : "idle"
  }

  property FileView stateFile: FileView {
    path: root.runtimeDir + "/voxtype/state"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.daemonState = "idle"
    onFileChanged: reload()
  }

  property FileView suppressionFile: FileView {
    path: root.runtimeDir + "/voxtype/osd_suppressed"
    watchChanges: true
    printErrors: false
    onLoaded: root.osdSuppressed = true
    onLoadFailed: root.osdSuppressed = false
    onFileChanged: reload()
  }
}
