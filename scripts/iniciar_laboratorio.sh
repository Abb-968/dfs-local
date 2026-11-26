#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="lscr.io/linuxserver/webtop:ubuntu-xfce"
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi

mkdir -p "$BASE"/{config,almacenamiento,registros}
mkdir -p "$BASE"/config/{namenode,datanode-a,datanode-b,cliente}
mkdir -p "$BASE"/almacenamiento/{nodo-a,nodo-b}

if ! "${DOCKER[@]}" network inspect dfs-net >/dev/null 2>&1; then
  "${DOCKER[@]}" network create --driver bridge --subnet 10.10.0.0/24 --gateway 10.10.0.254 dfs-net
fi

create_node() {
  local name="$1"
  local ip="$2"
  local port="$3"
  local config="$4"
  shift 4
  if "${DOCKER[@]}" container inspect "$name" >/dev/null 2>&1; then
    "${DOCKER[@]}" start "$name" >/dev/null
    return
  fi
  "${DOCKER[@]}" run -d \
    --name "$name" \
    --hostname "$name" \
    --network dfs-net \
    --ip "$ip" \
    --publish "127.0.0.1:${port}:3000" \
    --env PUID=1000 \
    --env PGID=1000 \
    --env TZ=America/Cancun \
    --shm-size=512m \
    --memory=1536m \
    --cpus=1.5 \
    --security-opt seccomp=unconfined \
    --volume "$BASE/config/$config:/config" \
    --volume "$BASE/dfs:/dfs:ro" \
    --volume "$BASE/registros:/registros" \
    "$@" \
    "$IMAGE" >/dev/null
}

create_node dfs-namenode 10.10.0.1 3001 namenode
create_node dfs-datanode-a 10.10.0.2 3002 datanode-a --volume "$BASE/almacenamiento/nodo-a:/storage"
create_node dfs-datanode-b 10.10.0.3 3003 datanode-b --volume "$BASE/almacenamiento/nodo-b:/storage"
create_node dfs-client 10.10.0.4 3004 cliente

for node in dfs-namenode dfs-datanode-a dfs-datanode-b dfs-client; do
  if ! "${DOCKER[@]}" exec "$node" command -v python3 >/dev/null; then
    "${DOCKER[@]}" exec "$node" sh -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3'
  fi
done

: > "$BASE/registros/namenode.log"
: > "$BASE/registros/datanode-a.log"
: > "$BASE/registros/datanode-b.log"

"${DOCKER[@]}" exec -d dfs-namenode sh -c 'python3 /dfs/namenode.py > /registros/namenode.log 2>&1'
sleep 2
"${DOCKER[@]}" exec -d -e NAMENODE_IP=10.10.0.1 -e STORAGE_DIR=/storage dfs-datanode-a sh -c 'python3 /dfs/datanode.py 10.10.0.2 > /registros/datanode-a.log 2>&1'
"${DOCKER[@]}" exec -d -e NAMENODE_IP=10.10.0.1 -e STORAGE_DIR=/storage dfs-datanode-b sh -c 'python3 /dfs/datanode.py 10.10.0.3 > /registros/datanode-b.log 2>&1'

if [[ ! -f "$BASE/registros/panel.pid" ]] || ! kill -0 "$(cat "$BASE/registros/panel.pid")" 2>/dev/null; then
  nohup python3 -m http.server 8080 --bind 127.0.0.1 --directory "$BASE/panel" > "$BASE/registros/panel.log" 2>&1 &
  echo "$!" > "$BASE/registros/panel.pid"
fi

printf '\nLaboratorio iniciado.\nPanel: http://127.0.0.1:8080\n'
printf 'DataNode A: %s\nDataNode B: %s\n' "$BASE/almacenamiento/nodo-a" "$BASE/almacenamiento/nodo-b"
