import hashlib
import json
import os
import socket
import sys

NAMENODE_IP = os.environ.get("NAMENODE_IP", "10.10.0.1")


def get_sha256(content):
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def request_namenode(payload):
    with socket.create_connection((NAMENODE_IP, 5000), timeout=5) as sock:
        sock.sendall(json.dumps(payload).encode("utf-8"))
        return json.loads(sock.recv(65536).decode("utf-8"))


def upload(filename, content):
    file_hash = get_sha256(content)
    res = request_namenode({
        "action": "register_file",
        "filename": filename,
        "hash": file_hash,
    })
    if res.get("status") != "OK" or not res.get("nodes"):
        print("[ERROR] No hay DataNodes activos registrados", flush=True)
        return 1

    nodes = res["nodes"]
    primary = nodes[0]
    secondary = nodes[1] if len(nodes) > 1 else None
    payload = {
        "action": "store",
        "filename": filename,
        "data": content,
        "replicate_to": secondary,
    }
    with socket.create_connection((primary, 5001), timeout=10) as sock:
        sock.sendall(json.dumps(payload).encode("utf-8"))
        d_res = json.loads(sock.recv(65536).decode("utf-8"))
    if d_res.get("status") != "OK":
        print(f"[ERROR] {d_res.get('msg')}", flush=True)
        return 1
    print(f"[ÉXITO] {filename} guardado en {primary}; réplica: {secondary}", flush=True)
    print(f"[SHA-256] {file_hash}", flush=True)
    return 0


def download(filename):
    res = request_namenode({"action": "lookup", "filename": filename})
    if res.get("status") != "OK":
        print(f"[ERROR] {res.get('msg')}", flush=True)
        return 1

    expected_hash = res["info"]["hash"]
    for node_ip in res["info"]["nodes"]:
        try:
            print(f"[INTENTO] Descargando desde {node_ip}", flush=True)
            with socket.create_connection((node_ip, 5001), timeout=3) as sock:
                sock.settimeout(3)
                sock.sendall(json.dumps({
                    "action": "retrieve",
                    "filename": filename,
                }).encode("utf-8"))
                d_res = json.loads(sock.recv(65536).decode("utf-8"))
            if d_res.get("status") != "OK":
                print(f"[ALERTA] {node_ip}: {d_res.get('msg')}", flush=True)
                continue
            content = d_res["data"]
            actual_hash = get_sha256(content)
            if actual_hash != expected_hash:
                print(f"[ALERTA] Integridad incorrecta en {node_ip}", flush=True)
                continue
            print(f"[CORRECTO] Recuperado desde {node_ip}; SHA-256 validado", flush=True)
            print(f"\n--- CONTENIDO ---\n{content}\n-----------------", flush=True)
            return 0
        except (OSError, json.JSONDecodeError) as exc:
            print(f"[FALLO] {node_ip} no disponible: {exc}", flush=True)
    print("[ERROR] Ningún DataNode pudo entregar una copia íntegra", flush=True)
    return 1


def main():
    if len(sys.argv) < 2:
        print("Uso: client.py upload ARCHIVO CONTENIDO | client.py download ARCHIVO")
        return 2
    action = sys.argv[1]
    if action == "upload" and len(sys.argv) == 4:
        return upload(sys.argv[2], sys.argv[3])
    if action == "download" and len(sys.argv) == 3:
        return download(sys.argv[2])
    print("Argumentos incorrectos")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
