#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ID="io.github.sh3nron.aura-voxtype-hud"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
VOXTYPE_CONFIG="${VOXTYPE_CONFIG:-$HOME/.config/voxtype/config.toml}"
HUD_CONFIG="$HOME/.config/voxtype/aura-strands-hud.json"
STATE_DIR="${AURA_VOXTYPE_STATE_DIR:-$HOME/.local/state/aura-voxtype-hud}"
UPSTREAM_COMMIT="0e69e737242df1d257b4e5e399b01ae1d7901375"
UPSTREAM_URL="https://raw.githubusercontent.com/DavidHDev/react-bits/$UPSTREAM_COMMIT/public/r/Strands-JS-CSS.json"
UPSTREAM_SHA256="${AURA_STRANDS_SHA256:-118c460fe92845a331b052c81201d6ae22ee039c029841de06ebc798c953599b}"
UPSTREAM_LICENSE_URL="https://raw.githubusercontent.com/DavidHDev/react-bits/$UPSTREAM_COMMIT/LICENSE.md"
UPSTREAM_LICENSE_SHA256="${AURA_STRANDS_LICENSE_SHA256:-f4c33af6739191537738662d223b68d77bc226f4b57ea883e16481d8cc5c73c9}"
UPSTREAM_MAX_BYTES=65536
LICENSE_MAX_BYTES=8192
QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
PALETTE="omarchy"
ASSUME_YES=false
DRY_RUN=false

usage() {
  printf '%s\n' "Usage: ./setup.sh [--yes] [--dry-run] [--palette omarchy|original]"
}

download_pinned() {
  local url="$1" target="$2" max_bytes="$3" label="$4" size
  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 60 --max-filesize "$max_bytes" \
    --output "$target" "$url"
  [[ -f "$target" && -s "$target" ]] || { echo "$label download is missing or empty" >&2; exit 1; }
  size="$(stat -c %s -- "$target")"
  (( size <= max_bytes )) || { echo "$label download exceeded the ${max_bytes}-byte limit" >&2; exit 1; }
}

while (($#)); do
  case "$1" in
    --yes|-y) ASSUME_YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --palette)
      shift
      [[ ${1:-} == omarchy || ${1:-} == original ]] || { echo "Invalid palette" >&2; exit 2; }
      PALETTE="$1"
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -f "$ROOT_DIR/manifest.json" ]] || { echo "Plugin manifest is missing" >&2; exit 1; }
[[ -f "$VOXTYPE_CONFIG" ]] || { echo "Voxtype config not found: $VOXTYPE_CONFIG" >&2; exit 1; }
for command in omarchy voxtype python3 systemctl curl sha256sum; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done
[[ -x /usr/bin/voxtype-audio-bridge ]] || { echo "Missing /usr/bin/voxtype-audio-bridge" >&2; exit 1; }
[[ -x "$QSB" ]] || { echo "Qt shader compiler not found: $QSB" >&2; exit 1; }

version="$(voxtype --version | awk '{print $NF}')"
[[ "$(printf '%s\n' 1.0.1 "$version" | sort -V | head -n1)" == 1.0.1 ]] || {
  echo "Voxtype 1.0.1 or newer is required (found $version)" >&2
  exit 1
}

if [[ "$ROOT_DIR" != "$PLUGIN_DIR" ]]; then
  echo "Expected the marketplace checkout at: $PLUGIN_DIR" >&2
  echo "Install it first with: omarchy plugin add <repository-url> --yes" >&2
  exit 1
fi

if [[ "$ASSUME_YES" != true ]]; then
  [[ -t 0 ]] || { echo "No terminal for confirmation; pass --yes" >&2; exit 1; }
  read -r -p "Disable Voxtype's stock OSD and activate Aura Voxtype HUD? [Y/n] " answer
  [[ ${answer:-Y} =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Would download and verify React Bits Strands at $UPSTREAM_COMMIT, compile it locally, back up $VOXTYPE_CONFIG, disable the stock OSD, enable $PLUGIN_ID, and restart Voxtype."
  exit 0
fi

upstream_tmp="$(mktemp "${TMPDIR:-/tmp}/aura-strands-upstream.XXXXXX")"
license_tmp="$(mktemp "${TMPDIR:-/tmp}/aura-strands-license.XXXXXX")"
generated_tmp="$(mktemp -d "${TMPDIR:-/tmp}/aura-strands-generated.XXXXXX")"
backup_dir=""
tmp_state=""
tmp_config=""
mutated=false
committed=false
hud_created=false
cleanup() {
  status=$?
  if [[ $status -ne 0 && "$mutated" == true && "$committed" != true ]]; then
    cp -a -- "$backup_dir/config.toml" "$VOXTYPE_CONFIG"
    [[ "$hud_created" == true ]] && rm -f -- "$HUD_CONFIG"
    systemctl --user restart voxtype.service >/dev/null 2>&1 || true
    echo "Setup failed; restored the pre-install Voxtype configuration." >&2
  fi
  [[ -z "$tmp_state" ]] || rm -f -- "$tmp_state"
  [[ -z "$tmp_config" ]] || rm -f -- "$tmp_config"
  rm -f -- "$upstream_tmp" "$license_tmp"
  rm -rf -- "$generated_tmp"
}
trap cleanup EXIT

if [[ -n ${AURA_STRANDS_SOURCE_FILE:-} ]]; then
  cp -- "$AURA_STRANDS_SOURCE_FILE" "$upstream_tmp"
else
  download_pinned "$UPSTREAM_URL" "$upstream_tmp" "$UPSTREAM_MAX_BYTES" "React Bits Strands"
fi
if [[ -n ${AURA_STRANDS_LICENSE_FILE:-} ]]; then
  cp -- "$AURA_STRANDS_LICENSE_FILE" "$license_tmp"
else
  download_pinned "$UPSTREAM_LICENSE_URL" "$license_tmp" "$LICENSE_MAX_BYTES" "React Bits license"
fi
printf '%s  %s\n' "$UPSTREAM_SHA256" "$upstream_tmp" | sha256sum --check --status || { echo "React Bits Strands integrity check failed" >&2; exit 1; }
printf '%s  %s\n' "$UPSTREAM_LICENSE_SHA256" "$license_tmp" | sha256sum --check --status || { echo "React Bits license integrity check failed" >&2; exit 1; }
python3 "$ROOT_DIR/tools/build-upstream.py" "$upstream_tmp" "$generated_tmp"
"$QSB" --qt6 --qsbversion 65 -O -o "$generated_tmp/strands.frag.qsb" "$generated_tmp/strands.frag"
"$QSB" --qt6 --qsbversion 65 -O -o "$generated_tmp/glass.frag.qsb" "$generated_tmp/glass.frag"

stamp="$(date +%Y%m%d%H%M%S)"
mkdir -p "$STATE_DIR/backups" "$(dirname -- "$HUD_CONFIG")"
backup_dir="$(mktemp -d "$STATE_DIR/backups/$stamp.XXXXXX")"
cp -a -- "$VOXTYPE_CONFIG" "$backup_dir/config.toml"
[[ -e "$HUD_CONFIG" ]] && cp -a -- "$HUD_CONFIG" "$backup_dir/aura-strands-hud.json"

state_file="$STATE_DIR/install-state"
tmp_state="$(mktemp "${TMPDIR:-/tmp}/aura-voxtype-state.XXXXXX")"
tmp_config="$(mktemp "${TMPDIR:-/tmp}/aura-voxtype-config.XXXXXX")"

python3 - "$VOXTYPE_CONFIG" "$tmp_config" "$tmp_state" <<'PY'
from pathlib import Path
import re, sys

source, output, state = map(Path, sys.argv[1:])
text = source.read_text()
lines = text.splitlines(keepends=True)
start = next((i for i, line in enumerate(lines) if re.match(r'^\s*\[osd\]\s*(?:#.*)?$', line)), None)
if start is None:
    prior = "absent"
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n[osd]\nenabled = false\n"
else:
    end = next((i for i in range(start + 1, len(lines)) if re.match(r'^\s*\[', lines[i])), len(lines))
    match = next((i for i in range(start + 1, end) if re.match(r'^\s*enabled\s*=', lines[i])), None)
    if match is None:
        prior = "missing"
        lines.insert(start + 1, "enabled = false\n")
    else:
        m = re.match(r'^(\s*enabled\s*=\s*)(true|false)(\s*(?:#.*)?\n?)$', lines[match], re.I)
        if not m:
            raise SystemExit("Unsupported [osd].enabled syntax; use true or false")
        prior = "true" if m.group(2).lower() == "true" else "false"
        lines[match] = m.group(1) + "false" + m.group(3)
    text = "".join(lines)
output.write_text(text)
state.write_text(prior + "\n")
PY

install -m 600 -- "$tmp_config" "$VOXTYPE_CONFIG"
mutated=true
mkdir -p "$STATE_DIR/generated" "$STATE_DIR/upstream"
install -m 600 -- "$upstream_tmp" "$STATE_DIR/upstream/Strands-JS-CSS.json"
install -m 600 -- "$license_tmp" "$STATE_DIR/upstream/LICENSE.md"
install -m 600 -- "$generated_tmp/strands.frag" "$generated_tmp/glass.frag" "$STATE_DIR/generated/"
install -m 600 -- "$generated_tmp/strands.frag.qsb" "$generated_tmp/glass.frag.qsb" "$STATE_DIR/generated/"
if [[ ! -e "$HUD_CONFIG" ]]; then
  source_config="$ROOT_DIR/default-config.json"
  [[ "$PALETTE" == original ]] && source_config="$ROOT_DIR/original-config.json"
  install -m 600 -- "$source_config" "$HUD_CONFIG"
  hud_created=true
fi
mkdir -p "$STATE_DIR"
[[ -e "$state_file" ]] || install -m 600 -- "$tmp_state" "$state_file"

omarchy plugin enable "$PLUGIN_ID" >/dev/null
systemctl --user restart voxtype.service
omarchy restart shell >/dev/null
committed=true

echo "Aura Voxtype HUD installed with the $PALETTE palette."
echo "Backup: $backup_dir"
echo "Configuration: $HUD_CONFIG"
echo "Pinned React Bits source and license: $STATE_DIR/upstream"
