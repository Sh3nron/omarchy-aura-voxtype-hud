#!/usr/bin/env python3
"""Convert a locally downloaded React Bits Strands item for Qt ShaderEffect.

This program intentionally contains no React Bits shader source. The input remains
under its upstream license and generated files must stay outside this repository.
"""
import json
import re
import sys
from pathlib import Path

MAX_COLORS = 8
MAX_STRANDS = 12

def shader_literal(component: str, name: str) -> str:
    match = re.search(rf"const\s+{name}\s*=\s*`([\s\S]*?)`;", component)
    if not match:
        raise SystemExit(f"Upstream format changed: {name} shader was not found")
    return match.group(1).replace("${MAX_COLORS}", str(MAX_COLORS)).replace("${MAX_STRANDS}", str(MAX_STRANDS))

def qt_header(shader: str) -> str:
    shader = re.sub(r"^#version\s+300\s+es\s*", "#version 440\n", shader)
    shader = re.sub(r"^precision\s+highp\s+float;\s*", "", shader, flags=re.M)
    shader = shader.replace(
        "gl_FragCoord.xy",
        "vec2(qt_TexCoord0.x * uResolution.x, (1.0 - qt_TexCoord0.y) * uResolution.y)",
    )
    return shader.replace(
        "out vec4 fragColor;",
        "layout(location = 0) in vec2 qt_TexCoord0;\nlayout(location = 0) out vec4 fragColor;",
    )

def convert_strands(shader: str) -> str:
    shader = qt_header(shader)
    declarations = ["uniform float uTime;", "uniform vec2 uResolution;", f"uniform vec3 uColors[{MAX_COLORS}];", "uniform int uColorCount;", "uniform int uStrandCount;", "uniform float uSpeed;", "uniform float uAmplitude;", "uniform float uWaviness;", "uniform float uThickness;", "uniform float uGlow;", "uniform float uTaper;", "uniform float uSpread;", "uniform float uHueShift;", "uniform float uIntensity;", "uniform float uOpacity;", "uniform float uScale;", "uniform float uSaturation;"]
    for declaration in declarations:
        if declaration not in shader:
            raise SystemExit(f"Upstream format changed: missing {declaration}")
        shader = shader.replace(declaration, "", 1)
    block = """layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix; float qt_Opacity; float uTime; vec2 uResolution;
  vec4 uColor0; vec4 uColor1; vec4 uColor2; vec4 uColor3;
  vec4 uColor4; vec4 uColor5; vec4 uColor6; vec4 uColor7;
  int uColorCount; int uStrandCount; float uSpeed; float uAmplitude;
  float uWaviness; float uThickness; float uGlow; float uTaper;
  float uSpread; float uHueShift; float uIntensity; float uOpacity;
  float uScale; float uSaturation;
};
"""
    shader = shader.replace("layout(location = 0) out vec4 fragColor;", block + "\nlayout(location = 0) out vec4 fragColor;")
    palette = """vec3 qtPaletteAt(int i) {
  if (i == 0) return uColor0.rgb; if (i == 1) return uColor1.rgb;
  if (i == 2) return uColor2.rgb; if (i == 3) return uColor3.rgb;
  if (i == 4) return uColor4.rgb; if (i == 5) return uColor5.rgb;
  if (i == 6) return uColor6.rgb; return uColor7.rgb;
}

"""
    marker = "vec3 samplePalette(float t) {"
    if marker not in shader:
        raise SystemExit("Upstream format changed: palette function was not found")
    shader = shader.replace(marker, palette + marker, 1)
    return re.sub(r"uColors\[([^]]+)\]", r"qtPaletteAt(\1)", shader)

def convert_glass(shader: str) -> str:
    shader = qt_header(shader)
    declarations = ["uniform sampler2D uScene;", "uniform vec2 uResolution;", "uniform float uRadius;", "uniform float uRefraction;", "uniform float uDispersion;"]
    for declaration in declarations:
        if declaration not in shader:
            raise SystemExit(f"Upstream format changed: missing {declaration}")
        shader = shader.replace(declaration, "", 1)
    uniforms = """layout(binding = 1) uniform sampler2D uScene;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix; float qt_Opacity; vec2 uResolution; float uRadius;
  float uRefraction; float uDispersion;
};
"""
    return shader.replace("layout(location = 0) out vec4 fragColor;", uniforms + "\nlayout(location = 0) out vec4 fragColor;")

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: build-upstream.py INPUT.json OUTPUT_DIRECTORY")
    data = json.loads(Path(sys.argv[1]).read_text())
    if data.get("name") != "Strands-JS-CSS":
        raise SystemExit("Downloaded registry item is not Strands-JS-CSS")
    files = {entry.get("path"): entry.get("content", "") for entry in data.get("files", [])}
    component = files.get("Strands.jsx")
    if not component:
        raise SystemExit("Downloaded registry item does not contain Strands.jsx")
    output = Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    (output / "strands.frag").write_text(convert_strands(shader_literal(component, "FRAG")))
    (output / "glass.frag").write_text(convert_glass(shader_literal(component, "GLASS_FRAG")))

if __name__ == "__main__":
    main()
