import json
import os
import socket
import sys
import threading
import time

NAMENODE_IP = os.environ.get("NAMENODE_IP", "10.10.0.1")
STORAGE_DIR = os.environ.get("STORAGE_DIR", "/storage")
PORT = 5001


def register_in_namenode(my_ip):
    for attempt in range(30):
        try:
            with socket.create_connection((NAMENODE_IP, 5000), timeout=3) as sock:
                payload = {"action": "register_node", "ip": my_ip}
                sock.sendall(json.dumps(payload).encode("utf-8"))
                res = json.loads(sock.recv(65536).decode("utf-8"))
                print(f"[REGISTRO] {res.get('msg')}", flush=True)
                return
        except OSError as exc:
            print(f"[ESPERA] NameNode no disponible ({attempt + 1}/30): {exc}", flush=True)
            time.sleep(2)
    raise RuntimeError("No fue posible registrarse en el NameNode")


def replicate_to_peer(peer_ip, filename, content):
    payload = {
        "action": "store",
        "filename": filename,
        "data": content,
        "replicate_to": None,
    }
    with socket.create_connection((peer_ip, PORT), timeout=5) as sock:
        sock.sendall(json.dumps(payload).encode("utf-8"))
        res = json.loads(sock.recv(65536).decode("utf-8"))
        if res.get("status") != "OK":
            raise RuntimeError(res.get("msg", "El nodo secundario rechazó la réplica"))
    print(f"[REPLICACIÓN] {filename} copiado en {peer_ip}", flush=True)


def handle_client(conn, addr):
    try:
        raw = conn.recv(65536).decode("utf-8")
        if not raw:
            return
        req = json.loads(raw)
        action = req.get("action")
        filename = os.path.basename(req.get("filename", ""))
        filepath = os.path.join(STORAGE_DIR, filename)

        if action == "store":
            content = req["data"]
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(content)
            print(f"[GUARDADO] {filepath}", flush=True)
            peer = req.get("replicate_to")
            if peer:
                replicate_to_peer(peer, filename, content)
            conn.sendall(json.dumps({"status": "OK"}).encode("utf-8"))
        elif action == "retrieve":
            if os.path.exists(filepath):
                with open(filepath, "r", encoding="utf-8") as file:
                    content = file.read()
                print(f"[LECTURA] {filename} enviado a {addr[0]}", flush=True)
                res = {"status": "OK", "data": content}
            else:
                res = {"status": "ERROR", "msg": "Archivo no existe"}
            conn.sendall(json.dumps(res).encode("utf-8"))
        else:
            conn.sendall(json.dumps({"status": "ERROR", "msg": "Acción no soportada"}).encode("utf-8"))
    except Exception as exc:
        print(f"[ERROR] {addr}: {exc}", flush=True)
        try:
            conn.sendall(json.dumps({"status": "ERROR", "msg": str(exc)}).encode("utf-8"))
        except OSError:
            pass
    finally:
        conn.close()


def start_datanode(my_ip):
    os.makedirs(STORAGE_DIR, exist_ok=True)
    register_in_namenode(my_ip)
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", PORT))
    server.listen(10)
    print(f"[DATANODE] {my_ip}:{PORT} | Almacenamiento: {STORAGE_DIR}", flush=True)
    while True:
        conn, addr = server.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Uso: python3 datanode.py IP_DEL_NODO")
    start_datanode(sys.argv[1])
