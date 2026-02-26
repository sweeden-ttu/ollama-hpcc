#!/usr/bin/env python3
"""
HPCC Ollama Local Proxy
Runs locally and forwards port 55077 -> 55078 (SSH tunnel endpoint)
The SSH tunnel: local:55078 -> login.hpcc.ttu.edu -> gpu-node:dynamic_port
"""

import socket
import sys

BUFFER_SIZE = 8192
LOCAL_PORT = 55077
TUNNEL_PORT = 55078


def forward(src, dst):
    """Forward data between two sockets."""
    try:
        while True:
            data = src.recv(BUFFER_SIZE)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try:
            src.close()
        except:
            pass
        try:
            dst.close()
        except:
            pass


def main():
    print(f"Starting Ollama proxy: {LOCAL_PORT} -> {TUNNEL_PORT}")
    print(f"SSH tunnel should forward: localhost:{TUNNEL_PORT} -> GPU node Ollama")
    print("To create tunnel: (1) /etc/slurm/scripts/interactive -p nocona, (2) note NODE and port, (3) ssh sweeden@login.hpcc.ttu.edu -L pppp:NODE:pppp")
    print("Press Ctrl+C to stop\n")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        server.bind(("127.0.0.1", LOCAL_PORT))
        server.listen(5)
        print(f"Listening on 127.0.0.1:{LOCAL_PORT}")

        while True:
            client_sock, addr = server.accept()
            print(f"Client connected from {addr}")

            try:
                tunnel_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                tunnel_sock.connect(("127.0.0.1", TUNNEL_PORT))

                t1 = threading.Thread(target=forward, args=(client_sock, tunnel_sock))
                t2 = threading.Thread(target=forward, args=(tunnel_sock, client_sock))

                t1.start()
                t2.start()

            except Exception as e:
                print(f"Error connecting to tunnel: {e}")
                client_sock.close()

    except KeyboardInterrupt:
        print("\nShutting down...")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        server.close()


if __name__ == "__main__":
    import threading

    main()
