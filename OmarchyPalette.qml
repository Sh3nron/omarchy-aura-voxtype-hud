import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root
  property color orange: "#F97316"
  property color magenta: "#7C3AED"
  property color cyan: "#06B6D4"

  function token(text, name, fallback) {
    const match = new RegExp("^\\s*" + name + "\\s*=\\s*\"(#[0-9a-fA-F]{6})\"", "m").exec(text || "")
    return match ? match[1] : fallback
  }

  function load() {
    const text = colors.text()
    orange = token(text, "orange", orange)
    magenta = token(text, "magenta", magenta)
    cyan = token(text, "cyan", cyan)
  }

  property FileView colors: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.load()
    onFileChanged: reload()
  }
}
