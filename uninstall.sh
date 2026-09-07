#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="io.github.sh3nron.aura-voxtype-hud"
VOXTYPE_CONFIG="${VOXTYPE_CONFIG:-$HOME/.config/voxtype/config.toml}"
HUD_CONFIG="$HOME/.config/voxtype/aura-strands-hud.json"
STATE_DIR="${AURA_VOXTYPE_STATE_DIR:-$HOME/.local/state/aura-voxtype-hud}"
STATE_FILE="$STATE_DIR/install-state"
ASSUME_YES=false

[[ ${1:-} == --yes || ${1:-} == -y ]] && ASSUME_YES=true
if [[ "$ASSUME_YES" != true ]]; then
  [[ -t 0 ]] || { echo "No terminal for confirmation; pass --yes" >&2; exit 1; }
  read -r -p "Restore the previous Voxtype OSD state and remove Aura HUD runtime config? [Y/n] " answer
  [[ ${answer:-Y} =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0
fi

for command in omarchy python3 systemctl; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

stamp="$(date +%Y%m%d%H%M%S)"
mkdir -p "$STATE_DIR/uninstall-backups"
backup_dir="$(mktemp -d "$STATE_DIR/uninstall-backups/$stamp.XXXXXX")"
[[ -e "$VOXTYPE_CONFIG" ]] && cp -a -- "$VOXTYPE_CONFIG" "$backup_dir/config.toml"
[[ -e "$HUD_CONFIG" ]] && cp -a -- "$HUD_CONFIG" "$backup_dir/aura-strands-hud.json"

if [[ -f "$STATE_FILE" && -f "$VOXTYPE_CONFIG" ]]; then
  prior="$(sed -n '1p' "$STATE_FILE")"
  tmp_config="$(mktemp "${TMPDIR:-/tmp}/aura-voxtype-uninstall.XXXXXX")"
  trap 'rm -f -- "$tmp_config"' EXIT
  python3 - "$VOXTYPE_CONFIG" "$tmp_config" "$prior" <<'PY'
from pathlib import Path
import re, sys

source, output = map(Path, sys.argv[1:3])
prior = sys.argv[3]
lines = source.read_text().splitlines(keepends=True)
start = next((i for i, line in enumerate(lines) if re.match(r'^\s*\[osd\]\s*(?:#.*)?$', line)), None)
if start is None:
    output.write_text("".join(lines)); raise SystemExit
end = next((i for i in range(start + 1, len(lines)) if re.match(r'^\s*\[', lines[i])), len(lines))
match = next((i for i in range(start + 1, end) if re.match(r'^\s*enabled\s*=', lines[i])), None)
if match is not None and re.match(r'^\s*enabled\s*=\s*false(?:\s*(?:#.*)?)?$', lines[match].rstrip(), re.I):
    if prior in ("absent", "missing"):
        del lines[match]
        if prior == "absent" and not any(line.strip() and not line.lstrip().startswith("#") for line in lines[start + 1:end - 1]):
            del lines[start]
    elif prior == "true":
        lines[match] = re.sub(r'(?i)(^\s*enabled\s*=\s*)false', r'\1true', lines[match])
output.write_text("".join(lines))
PY
  install -m 600 -- "$tmp_config" "$VOXTYPE_CONFIG"
fi

omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
rm -f -- "$HUD_CONFIG" "$STATE_FILE"
rm -rf -- "$STATE_DIR/generated" "$STATE_DIR/upstream"
systemctl --user restart voxtype.service
omarchy restart shell >/dev/null

echo "Aura Voxtype HUD removed. Backup: $backup_dir"
echo "Now remove the checkout with: omarchy plugin remove $PLUGIN_ID --yes"
