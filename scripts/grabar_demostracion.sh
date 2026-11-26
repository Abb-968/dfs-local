#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi
rm -f "$BASE/registros/listo_para_fallo"
for node in dfs-namenode dfs-datanode-a dfs-datanode-b dfs-client; do
  "${DOCKER[@]}" exec "$node" pkill xfce4-terminal 2>/dev/null || true
done
"$BASE/scripts/iniciar_vista_grabacion.sh"

open_terminal() {
  local node="$1"
  local command="$2"
  "${DOCKER[@]}" exec -d \
    --user abc \
    --env DISPLAY=:1 \
    --env HOME=/config \
    "$node" xfce4-terminal --geometry=100x24 --command="$command"
}

sleep 3
open_terminal dfs-namenode 'tail -f /registros/namenode.log'
open_terminal dfs-datanode-a 'tail -f /registros/datanode-a.log'
open_terminal dfs-datanode-b 'tail -f /registros/datanode-b.log'
sleep 4
open_terminal dfs-client 'bash /dfs/demo_cliente.sh'

for _ in {1..45}; do
  [[ -f "$BASE/registros/listo_para_fallo" ]] && break
  sleep 1
done
if [[ ! -f "$BASE/registros/listo_para_fallo" ]]; then
  "$BASE/scripts/finalizar_grabacion.sh"
  printf 'No se pudo iniciar la prueba de fallo; revisa los registros.\n' >&2
  exit 1
fi

sleep 2
"${DOCKER[@]}" stop dfs-datanode-a >/dev/null
sleep 42
"$BASE/scripts/finalizar_grabacion.sh"

"${DOCKER[@]}" start dfs-datanode-a >/dev/null
sleep 4
"${DOCKER[@]}" exec -d -e NAMENODE_IP=10.10.0.1 -e STORAGE_DIR=/storage dfs-datanode-a sh -c 'python3 /dfs/datanode.py 10.10.0.2 >> /registros/datanode-a.log 2>&1'
printf 'Video guardado en %s/evidencias/demostracion_dfs.mp4\n' "$BASE"
