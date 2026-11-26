#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$BASE/registros/ffmpeg.pid" ]]; then
  pid="$(cat "$BASE/registros/ffmpeg.pid")"
  if kill -0 "$pid" 2>/dev/null; then
    kill -INT "$pid"
    for _ in {1..30}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
  fi
  rm -f "$BASE/registros/ffmpeg.pid"
fi

for name in navegador xvfb; do
  if [[ -f "$BASE/registros/$name.pid" ]]; then
    kill "$(cat "$BASE/registros/$name.pid")" 2>/dev/null || true
    rm -f "$BASE/registros/$name.pid"
  fi
done
pkill -f "user-data-dir=$BASE/navegador-perfil" 2>/dev/null || true
