#!/usr/bin/env bash
# generate_feature_graphic.sh
# Generates a Play Store feature graphic (1024x500 px) from project tokens.
#
# Prerequisites: ImageMagick (`convert`) on PATH.
# If ImageMagick is absent, prints the command and exits 2.
#
# Usage:
#   ${CLAUDE_SKILL_DIR}/scripts/generate_feature_graphic.sh
#     --app-name "My App"
#     [--tagline "One-liner value prop"]
#     [--primary "#6750A4"]
#     [--on-primary "#FFFFFF"]
#     [--font-size 48]
#     [--output publish/play_feature_graphic.png]
#     [--layout left|center]     # center (default) or left
#
# Without ImageMagick: prints a Pencil MCP batch_design payload JSON to stdout
# and exits 2 so the skill can route to the Pencil path.

set -euo pipefail

APP_NAME=""
TAGLINE=""
PRIMARY="#6750A4"
ON_PRIMARY="#FFFFFF"
FONT_SIZE=48
OUTPUT="publish/play_feature_graphic.png"
LAYOUT="center"
WIDTH=1024
HEIGHT=500
SAFE_CENTER=600

usage() {
  echo "Usage: $0 --app-name NAME [--tagline TAGLINE] [--primary COLOR] [--on-primary COLOR] [--font-size N] [--output PATH] [--layout center|left]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name) APP_NAME="$2"; shift 2 ;;
    --tagline) TAGLINE="$2"; shift 2 ;;
    --primary) PRIMARY="$2"; shift 2 ;;
    --on-primary) ON_PRIMARY="$2"; shift 2 ;;
    --font-size) FONT_SIZE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --layout) LAYOUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
  echo "ERROR: --app-name is required"
  usage
fi

mkdir -p "$(dirname "$OUTPUT")"

if ! command -v convert &>/dev/null; then
  cat <<JSON >&2
{"status":"no_imagemagick","fallback":"pencil","width":$WIDTH,"height":$HEIGHT,
 "background":"$PRIMARY","app_name":"$APP_NAME","tagline":"$TAGLINE",
 "on_primary":"$ON_PRIMARY","font_size":$FONT_SIZE,"layout":"$LAYOUT",
 "safe_center_px":$SAFE_CENTER}
JSON
  exit 2
fi

# Build ImageMagick command — center layout
convert -size "${WIDTH}x${HEIGHT}" "xc:$PRIMARY" \
  -fill "$ON_PRIMARY" \
  -font Helvetica-Bold \
  -pointsize "$FONT_SIZE" \
  -gravity Center \
  -annotate +0-30 "$APP_NAME" \
  "$OUTPUT"

# Tagline below the name
if [[ -n "$TAGLINE" ]]; then
  convert "$OUTPUT" \
    -fill "$ON_PRIMARY" -channel A -evaluate multiply 0.8 +channel \
    -font Helvetica \
    -pointsize 18 \
    -gravity Center \
    -annotate +0+30 "$TAGLINE" \
    "$OUTPUT"
fi

echo "✅ Feature graphic written to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
echo "   Dimensions: ${WIDTH}x${HEIGHT} px"
echo ""
echo "Next: generate phone screenshots via Pencil get_screenshot or:"
echo "  flutter screenshot --device-id <id> --type=device"
