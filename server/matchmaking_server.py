import socket
import threading
import time

HOST = "0.0.0.0"
PORT = 5000
TIMEOUT = 30

rooms = {}
lock = threading.Lock()

def cleanup_room(room_name):
    with lock:
        if room_name in rooms:
            players = rooms[room_name]
            for addr in players:
                try:
                    server_socket.sendto(b"CANCEL", addr)
                except Exception:
                    pass
            del rooms[room_name]

def handle_client(data, addr, server_socket):
    message = data.decode("utf-8").strip()

    if message.startswith("ROOM "):
        room_name = message[5:]
        with lock:
            if room_name not in rooms:
                rooms[room_name] = []
            players = rooms[room_name]

            if len(players) >= 2:
                server_socket.sendto(b"FULL", addr)
                return

            if addr in players:
                server_socket.sendto(b"ALREADY_IN", addr)
                return

            players.append(addr)
            print(f"[{room_name}] Player joined: {addr[0]}:{addr[1]} ({len(players)}/2)")

            if len(players) == 2:
                p1, p2 = players
                server_socket.sendto(f"PEER {p2[0]} {p2[1]}".encode(), p1)
                server_socket.sendto(f"PEER {p1[0]} {p1[1]}".encode(), p2)
                print(f"[{room_name}] Match found! {p1[0]}:{p1[1]} <-> {p2[0]}:{p2[1]}")
                del rooms[room_name]
            else:
                server_socket.sendto(b"WAITING", addr)

    elif message.startswith("LEAVE "):
        room_name = message[6:]
        with lock:
            if room_name in rooms:
                players = rooms[room_name]
                if addr in players:
                    players.remove(addr)
                    print(f"[{room_name}] Player left: {addr[0]}:{addr[1]} ({len(players)}/2)")
                    if len(players) == 1:
                        other = players[0]
                        try:
                            server_socket.sendto(b"CANCEL", other)
                        except Exception:
                            pass
                    if not players:
                        del rooms[room_name]

    elif message == "PING":
        pass

def timeout_checker(server_socket):
    while True:
        time.sleep(1)
        now = time.time()
        with lock:
            to_delete = []
            for room_name, players in list(rooms.items()):
                if len(players) == 1:
                    for addr in players:
                        try:
                            server_socket.sendto(b"TIMEOUT", addr)
                        except Exception:
                            pass
                    to_delete.append(room_name)
            for room_name in to_delete:
                del rooms[room_name]

server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server_socket.bind((HOST, PORT))
print(f"Matchmaking server running on {HOST}:{PORT}")

timeout_thread = threading.Thread(target=timeout_checker, args=(server_socket,), daemon=True)
timeout_thread.start()

while True:
    try:
        data, addr = server_socket.recvfrom(1024)
        threading.Thread(target=handle_client, args=(data, addr, server_socket), daemon=True).start()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        break
    except Exception as e:
        print(f"Error: {e}")

server_socket.close()
