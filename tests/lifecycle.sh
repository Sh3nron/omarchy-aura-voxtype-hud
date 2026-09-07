#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/aura-voxtype-lifecycle.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT

export HOME="$fixture/home"
export AURA_TEST_LOG="$fixture/commands.log"
export AURA_VOXTYPE_STATE_DIR="$HOME/.local/state/aura-voxtype-hud"
export PATH="$ROOT/tests/mocks:$PATH"
export AURA_STRANDS_SOURCE_FILE="$ROOT/tests/fixtures/strands-shape.json"
export AURA_STRANDS_LICENSE_FILE="$ROOT/tests/fixtures/upstream-license.txt"
export AURA_STRANDS_SHA256="$(sha256sum "$AURA_STRANDS_SOURCE_FILE" | awk '{print $1}')"
export AURA_STRANDS_LICENSE_SHA256="$(sha256sum "$AURA_STRANDS_LICENSE_FILE" | awk '{print $1}')"
plugin="$HOME/.config/omarchy/plugins/io.github.sh3nron.aura-voxtype-hud"
mkdir -p "$plugin" "$HOME/.config/voxtype"
cp -a "$ROOT/." "$plugin/"
chmod +x "$plugin/setup.sh" "$plugin/uninstall.sh"

config="$HOME/.config/voxtype/config.toml"
printf '%s\n' \
  'state_file = "auto"' \
  'engine = "whisper"' \
  '' \
  '[osd]' \
  'enabled = true' \
  'frontend = "quickshell"' \
  '' \
  '[status]' \
  'icon_theme = "emoji"' > "$config"

"$plugin/setup.sh" --yes --palette original
grep -q '^enabled = false$' "$config"
grep -q '^frontend = "quickshell"$' "$config"
grep -q '"paletteMode": "original"' "$HOME/.config/voxtype/aura-strands-hud.json"
[[ $(sed -n '1p' "$AURA_VOXTYPE_STATE_DIR/install-state") == true ]]
[[ -s "$AURA_VOXTYPE_STATE_DIR/generated/strands.frag.qsb" ]]
[[ -s "$AURA_VOXTYPE_STATE_DIR/upstream/LICENSE.md" ]]

# A repeated setup must retain the first install's restoration baseline.
"$plugin/setup.sh" --yes --palette omarchy
[[ $(sed -n '1p' "$AURA_VOXTYPE_STATE_DIR/install-state") == true ]]

"$plugin/uninstall.sh" --yes
grep -q '^enabled = true$' "$config"
grep -q '^frontend = "quickshell"$' "$config"
[[ ! -e "$HOME/.config/voxtype/aura-strands-hud.json" ]]
[[ ! -e "$AURA_VOXTYPE_STATE_DIR/generated" ]]
[[ ! -e "$AURA_VOXTYPE_STATE_DIR/upstream" ]]
grep -q 'omarchy plugin enable io.github.sh3nron.aura-voxtype-hud' "$AURA_TEST_LOG"
grep -q 'omarchy plugin disable io.github.sh3nron.aura-voxtype-hud' "$AURA_TEST_LOG"

echo "Lifecycle checks passed."
