#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
QMLLINT="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"

python3 -m json.tool "$ROOT/manifest.json" >/dev/null
python3 -m json.tool "$ROOT/default-config.json" >/dev/null
python3 -m json.tool "$ROOT/original-config.json" >/dev/null
python3 -m json.tool "$ROOT/tests/fixtures/strands-shape.json" >/dev/null

tmp="$(mktemp -d "${TMPDIR:-/tmp}/aura-voxtype-tests.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
python3 "$ROOT/tools/build-upstream.py" "$ROOT/tests/fixtures/strands-shape.json" "$tmp/generated"
"$QSB" --qt6 --qsbversion 65 -O -o "$tmp/strands.qsb" "$tmp/generated/strands.frag"
"$QSB" --qt6 --qsbversion 65 -O -o "$tmp/glass.qsb" "$tmp/generated/glass.frag"
"$QSB" -d "$tmp/strands.qsb" >/dev/null
"$QSB" -d "$tmp/glass.qsb" >/dev/null

"$QMLLINT" -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
  "$ROOT/Service.qml" "$ROOT/HudConfig.qml" "$ROOT/OmarchyPalette.qml" \
  "$ROOT/VoxtypeState.qml" "$ROOT/AudioBridge.qml" \
  "$ROOT/StrandsEffect.qml" "$ROOT/StrandsSurface.qml" "$ROOT/dev-shell.qml" \
  "$ROOT/dev-visual.qml" "$ROOT/dev-preview.qml"

bash -n "$ROOT/setup.sh" "$ROOT/uninstall.sh" "$ROOT/tests/check.sh"
python3 - "$ROOT/tools/build-upstream.py" <<'PY'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
compile(source, sys.argv[1], "exec")
PY
"$ROOT/tests/lifecycle.sh"
echo "All static checks passed."
