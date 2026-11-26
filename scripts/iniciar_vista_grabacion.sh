#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$BASE/navegador-perfil" "$BASE/evidencias"

if [[ ! -f "$BASE/registros/xvfb.pid" ]] || ! kill -0 "$(cat "$BASE/registros/xvfb.pid")" 2>/dev/null; then
  nohup Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp > "$BASE/registros/xvfb.log" 2>&1 &
  echo "$!" > "$BASE/registros/xvfb.pid"
  sleep 2
fi

BROWSER="$(command -v brave || command -v brave-browser || command -v google-chrome)"
if [[ ! -f "$BASE/registros/navegador.pid" ]] || ! kill -0 "$(cat "$BASE/registros/navegador.pid")" 2>/dev/null; then
  DISPLAY=:99 WAYLAND_DISPLAY= XDG_SESSION_TYPE=x11 nohup "$BROWSER" \
    --user-data-dir="$BASE/navegador-perfil" \
    --no-first-run \
    --no-default-browser-check \
    --disable-session-crashed-bubble \
    --ozone-platform=x11 \
    --disable-gpu \
    --disable-translate \
    --disable-features=Translate,TranslateUI,BraveTranslate \
    --window-size=1920,1080 \
    --window-position=0,0 \
    --kiosk \
    http://127.0.0.1:8080 > "$BASE/registros/navegador.log" 2>&1 &
  echo "$!" > "$BASE/registros/navegador.pid"
fi

sleep 12
if [[ ! -f "$BASE/registros/ffmpeg.pid" ]] || ! kill -0 "$(cat "$BASE/registros/ffmpeg.pid")" 2>/dev/null; then
  nohup ffmpeg -y \
    -f x11grab -video_size 1920x1080 -framerate 30 -i :99.0 \
    -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
    -movflags +faststart "$BASE/evidencias/demostracion_dfs.mp4" \
    > "$BASE/registros/ffmpeg.log" 2>&1 &
  echo "$!" > "$BASE/registros/ffmpeg.pid"
fi
