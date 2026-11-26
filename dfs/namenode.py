import json
import socket
import threading

HOST = "0.0.0.0"
PORT = 5000
METADATA_DB = {}
ACTIVE_DATANODES = []
LOCK = threading.Lock()


def handle_client(conn, addr):
    try:
        raw = conn.recv(65536).decode("utf-8")
        if not raw:
            return
        req = json.loads(raw)
        action = req.get("action")
        with LOCK:
            if action == "register_node":
                node_ip = req["ip"]
                if node_ip not in ACTIVE_DATANODES:
                    ACTIVE_DATANODES.append(node_ip)
                res = {"status": "OK", "msg": f"DataNode {node_ip} registrado"}
                print(f"[REGISTRO] {node_ip} | Activos: {ACTIVE_DATANODES}", flush=True)
            elif action == "register_file":
                nodes = list(ACTIVE_DATANODES)
                METADATA_DB[req["filename"]] = {"hash": req["hash"], "nodes": nodes}
                res = {"status": "OK", "nodes": nodes}
                print(f"[METADATOS] {req['filename']} -> {nodes}", flush=True)
            elif action == "lookup":
                if req["filename"] in METADATA_DB:
                    res = {"status": "OK", "info": METADATA_DB[req["filename"]]}
                else:
                    res = {"status": "ERROR", "msg": "Archivo no encontrado"}
            elif action == "list_nodes":
                res = {"status": "OK", "nodes": list(ACTIVE_DATANODES)}
            else:
                res = {"status": "ERROR", "msg": "Acción no soportada"}
        conn.sendall(json.dumps(res).encode("utf-8"))
    except Exception as exc:
        print(f"[ERROR] {addr}: {exc}", flush=True)
    finally:
        conn.close()


def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(10)
    print(f"[NAMENODE] Activo en {HOST}:{PORT}", flush=True)
    while True:
        conn, addr = server.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    start_server()
