#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi
"${DOCKER[@]}" stop dfs-client dfs-datanode-b dfs-datanode-a dfs-namenode
if [[ -f "$BASE/registros/panel.pid" ]]; then
  kill "$(cat "$BASE/registros/panel.pid")" 2>/dev/null || true
  rm -f "$BASE/registros/panel.pid"
fi
