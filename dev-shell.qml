import QtQuick
import Quickshell

ShellRoot {
  Service { id: service }
  Timer {
    interval: 1500
    running: true
    onTriggered: Qt.quit()
  }
}
