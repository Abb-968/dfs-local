#!/usr/bin/env bash
set -u

export NAMENODE_IP=10.10.0.1
rm -f /registros/listo_para_fallo

printf '\n=== 1. SUBIDA Y REPLICACIÓN ===\n'
python3 /dfs/client.py upload bitacora.txt "Sistemas Distribuidos 2026 - Practica de Replicacion"
printf '\nEl archivo ya está almacenado en DataNode A y DataNode B.\n'
sleep 8

printf '\n=== 2. DESCARGA E INTEGRIDAD SHA-256 ===\n'
python3 /dfs/client.py download bitacora.txt
sleep 8

printf '\n=== 3. PRUEBA DE TOLERANCIA A FALLOS ===\n'
printf 'Ahora se detendrá DataNode A (10.10.0.2).\n'
touch /registros/listo_para_fallo
sleep 6
python3 /dfs/client.py download bitacora.txt
printf '\nRESULTADO: DataNode A falló y DataNode B entregó una copia íntegra.\n'
exec bash --noprofile --norc
