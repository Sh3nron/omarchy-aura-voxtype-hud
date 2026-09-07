import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  readonly property string path: Quickshell.env("HOME") + "/.config/voxtype/aura-strands-hud.json"
  property var values: defaults()

  function defaults() {
    return {
      "version": 1,
      "paletteMode": "omarchy",
      "colors": ["#F97316", "#7C3AED", "#06B6D4"],
      "count": 3,
      "speed": 0.5,
      "amplitude": 1.0,
      "waviness": 1.0,
      "thickness": 0.7,
      "glow": 2.6,
      "taper": 3.0,
      "spread": 1.0,
      "hueShift": 0.0,
      "intensity": 0.6,
      "saturation": 2.0,
      "opacity": 1.0,
      "scale": 1.5,
      "glass": false,
      "refraction": 1.0,
      "dispersion": 1.0,
      "glassSize": 1.0,
      "width": 640,
      "height": 480,
      "bottomMargin": 24,
      "audioResponse": true,
      "voiceHangMs": 2000,
      "flowAttackMs": 420,
      "flowReleaseMs": 620,
      "idleMotion": 0.32,
      "idleBrightness": 0.45
    }
  }

  function number(value, fallback, low, high) {
    const n = Number(value)
    return Number.isFinite(n) ? Math.max(low, Math.min(high, n)) : fallback
  }

  function normalize(input) {
    const d = defaults()
    const p = input && typeof input === "object" ? input : {}
    const mode = ["omarchy", "original", "custom"].indexOf(String(p.paletteMode)) >= 0
      ? String(p.paletteMode) : d.paletteMode
    const colors = Array.isArray(p.colors)
      ? p.colors.slice(0, 8).filter(c => /^#[0-9a-fA-F]{6}$/.test(String(c))) : d.colors
    return {
      "version": 1,
      "paletteMode": mode,
      "colors": colors.length ? colors : d.colors,
      "count": Math.round(number(p.count, d.count, 1, 12)),
      "speed": number(p.speed, d.speed, 0, 3),
      "amplitude": number(p.amplitude, d.amplitude, 0, 3),
      "waviness": number(p.waviness, d.waviness, 0.2, 3),
      "thickness": number(p.thickness, d.thickness, 0.2, 4),
      "glow": number(p.glow, d.glow, 0.3, 3),
      "taper": number(p.taper, d.taper, 0.5, 6),
      "spread": number(p.spread, d.spread, 0, 3),
      "hueShift": number(p.hueShift, d.hueShift, 0, 1),
      "intensity": number(p.intensity, d.intensity, 0, 1),
      "saturation": number(p.saturation, d.saturation, 0, 2),
      "opacity": number(p.opacity, d.opacity, 0, 1),
      "scale": number(p.scale, d.scale, 0.3, 3),
      "glass": p.glass === true,
      "refraction": number(p.refraction, d.refraction, 0, 3),
      "dispersion": number(p.dispersion, d.dispersion, 0, 4),
      "glassSize": number(p.glassSize, d.glassSize, 0.3, 1),
      "width": Math.round(number(p.width, d.width, 160, 1280)),
      "height": Math.round(number(p.height, d.height, 120, 960)),
      "bottomMargin": Math.round(number(p.bottomMargin, d.bottomMargin, 0, 512)),
      "audioResponse": p.audioResponse !== false,
      "voiceHangMs": number(p.voiceHangMs, d.voiceHangMs, 100, 2000),
      "flowAttackMs": number(p.flowAttackMs, d.flowAttackMs, 50, 2000),
      "flowReleaseMs": number(p.flowReleaseMs, d.flowReleaseMs, 100, 3000),
      "idleMotion": number(p.idleMotion, d.idleMotion, 0, 1),
      "idleBrightness": number(p.idleBrightness, d.idleBrightness, 0, 1)
    }
  }

  function load(text) {
    try {
      values = normalize(JSON.parse(text || "{}"))
    } catch (error) {
      console.warn("aura-voxtype-hud: invalid config; using defaults:", error)
      values = defaults()
    }
  }

  property FileView file: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.values = root.defaults()
    onFileChanged: reload()
  }
}
