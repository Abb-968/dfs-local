#!/usr/bin/env bash
set -euo pipefail
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi

open_terminal() {
  local node="$1"
  local command="$2"
  "${DOCKER[@]}" exec -d \
    --user abc \
    --env DISPLAY=:1 \
    --env HOME=/config \
    "$node" xfce4-terminal --geometry=100x24 --command="$command"
}

open_terminal dfs-namenode 'tail -f /registros/namenode.log'
open_terminal dfs-datanode-a 'tail -f /registros/datanode-a.log'
open_terminal dfs-datanode-b 'tail -f /registros/datanode-b.log'
open_terminal dfs-client 'bash --noprofile --norc'
