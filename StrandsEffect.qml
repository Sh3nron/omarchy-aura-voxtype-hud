import QtQuick
import Quickshell

Item {
  id: root
  property var config
  property var paletteSource
  property real flow: 0
  property real elapsed: 0
  readonly property var settings: config ? config.values : ({})
  readonly property string shaderDir: Quickshell.env("HOME") + "/.local/state/aura-voxtype-hud/generated"
  readonly property var activeColors: settings.paletteMode === "omarchy" && paletteSource
    ? [paletteSource.orange, paletteSource.magenta, paletteSource.cyan]
    : (settings.colors || ["#F97316", "#7C3AED", "#06B6D4"])

  function colorAt(i) {
    return activeColors[Math.min(i, Math.max(0, activeColors.length - 1))] || "#ffffff"
  }
  readonly property real flowResponse: Math.max(0, Math.min(1, flow))
  readonly property real idleMotion: settings.idleMotion === undefined ? 0.32 : settings.idleMotion
  readonly property real idleBrightness: settings.idleBrightness === undefined ? 0.45 : settings.idleBrightness

  ShaderEffect {
    id: strands
    anchors.fill: parent
    property real uTime: root.elapsed
    property size uResolution: Qt.size(width, height)
    property color uColor0: root.colorAt(0)
    property color uColor1: root.colorAt(1)
    property color uColor2: root.colorAt(2)
    property color uColor3: root.colorAt(3)
    property color uColor4: root.colorAt(4)
    property color uColor5: root.colorAt(5)
    property color uColor6: root.colorAt(6)
    property color uColor7: root.colorAt(7)
    property int uColorCount: Math.max(1, Math.min(8, root.activeColors.length))
    property int uStrandCount: root.settings.count || 3
    // The surface integrates a smoothly varying clock rate. Keeping this
    // upstream speed fixed preserves phase continuity through transitions.
    property real uSpeed: root.settings.speed === undefined ? 0.5 : root.settings.speed
    property real uAmplitude: (root.settings.amplitude === undefined ? 1 : root.settings.amplitude) * (0.28 + root.flowResponse * 0.72)
    property real uWaviness: (root.settings.waviness || 1) * (0.55 + root.flowResponse * 0.45)
    property real uThickness: (root.settings.thickness || 0.7) * (0.50 + root.flowResponse * 0.50)
    property real uGlow: (root.settings.glow || 2.6) * (root.idleBrightness + root.flowResponse * (1 - root.idleBrightness))
    property real uTaper: root.settings.taper || 3
    property real uSpread: (root.settings.spread === undefined ? 1 : root.settings.spread) * (0.30 + root.flowResponse * 0.70)
    property real uHueShift: root.settings.hueShift || 0
    property real uIntensity: (root.settings.intensity === undefined ? 0.6 : root.settings.intensity) * (0.35 + root.flowResponse * 0.65)
    property real uOpacity: root.settings.opacity === undefined ? 1 : root.settings.opacity
    property real uScale: root.settings.scale || 1.5
    property real uSaturation: root.settings.saturation === undefined ? 2 : root.settings.saturation
    fragmentShader: "file://" + root.shaderDir + "/strands.frag.qsb"
  }

  ShaderEffectSource {
    id: scene
    anchors.fill: parent
    sourceItem: strands
    hideSource: root.settings.glass === true
    live: true
    visible: false
    textureSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(height)))
  }

  ShaderEffect {
    anchors.fill: parent
    visible: root.settings.glass === true
    property variant uScene: scene
    property size uResolution: Qt.size(width, height)
    property real uRadius: 0.46 * (root.settings.glassSize || 1)
    property real uRefraction: root.settings.refraction === undefined ? 1 : root.settings.refraction
    property real uDispersion: root.settings.dispersion === undefined ? 1 : root.settings.dispersion
    fragmentShader: "file://" + root.shaderDir + "/glass.frag.qsb"
  }
}
