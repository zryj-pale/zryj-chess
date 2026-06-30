extends Node

signal player_connected
signal player_disconnected
signal game_started(white_pieces: Array, black_pieces: Array, host_is_white: bool)
signal move_received(from: Vector2i, to: Vector2i)
signal coinflip_received(result: String)

var peer = null
var is_host = false
var player_id = 0
var upnp = null

var my_white_pieces = []
var my_black_pieces = []
var host_is_white = true

func host_game(port: int = 7777):
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 1)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	player_id = 1
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	setup_upnp(port)
	return OK

func setup_upnp(port: int):
	upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(port, port, "zryj chess", "UDP")
		upnp.add_port_mapping(port, port, "zryj chess", "TCP")

func join_game(ip: String, port: int = 7777):
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	player_id = 2
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK

func close_connection():
	if upnp:
		upnp.clear_port_mappings()
		upnp = null
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	player_id = 0
	my_white_pieces = []
	my_black_pieces = []
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)

func _on_peer_connected(id: int):
	player_id = id
	player_connected.emit()

func _on_connected_to_server():
	player_id = 1
	player_connected.emit()

func _on_peer_disconnected(id: int):
	player_disconnected.emit()

func set_my_positions(white_pieces: Array, black_pieces: Array):
	my_white_pieces = white_pieces
	my_black_pieces = black_pieces

@rpc("authority", "call_remote", "reliable")
func sync_coinflip_result(result: String):
	if result == "orzel":
		host_is_white = true
	else:
		host_is_white = false
	coinflip_received.emit(result)

func broadcast_coinflip(result: String):
	if result == "orzel":
		host_is_white = true
	else:
		host_is_white = false
	sync_coinflip_result.rpc(result)

@rpc("authority", "call_remote", "reliable")
func sync_game_start(white_pieces: Array, black_pieces: Array, _host_is_white: bool):
	host_is_white = _host_is_white
	game_started.emit(white_pieces, black_pieces, host_is_white)

@rpc("any_peer", "call_remote", "reliable")
func send_move(from: Vector2i, to: Vector2i):
	move_received.emit(from, to)

func start_game():
	var final_white = my_white_pieces if host_is_white else my_black_pieces
	var final_black = my_black_pieces if host_is_white else my_white_pieces
	sync_game_start.rpc(final_white, final_black, host_is_white)

func submit_move(from: Vector2i, to: Vector2i):
	if is_host:
		send_move.rpc(from, to)
	else:
		send_move.rpc_id(1, from, to)
