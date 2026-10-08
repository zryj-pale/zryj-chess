extends SceneTree

# godot --headless --path . --fixed-fps 120 --script res://tests/test_coin_online.gd
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	# Load the actual integration scripts too, catching broken signal signatures.
	check("main loads", load("res://scripts/main.gd") != null)
	var network = root.get_node("NetworkManager")
	check("result initially unknown", network.coin_result == "" and network.initial_turn == "")
	network._receive_payload({"type": "action", "action": {"type": "coin_ready"}})
	check("readiness retained before scene connects", network.coin_peer_ready)
	network._receive_payload({"type": "action", "action": {"type": "coin_finished"}})
	check("completion retained", network.coin_peer_finished)
	network.reset()
	check("new room clears coin state", not network.coin_peer_ready and not network.coin_peer_finished and network.coin_result == "")
	var board = load("res://scripts/main.gd").new()
	network.is_online = true
	board._on_coin_result("reszka")
	check("landing sets shared first turn", board.kolor_posuniecia == "c" and network.initial_turn == "c" and network.coin_result == "reszka")
	board._on_coin_finished()
	check("local finish waits for peer", not board.input_enabled)
	board._on_network_action({"type": "move", "from_x": 0, "from_y": 0, "to_x": 0, "to_y": 1})
	check("early move buffered", board.queued_board_actions.size() == 1)
	network.coin_peer_finished = true
	board._on_network_action({"type": "coin_finished"})
	check("both finished unlock and drain queue", board.input_enabled and board.queued_board_actions.is_empty())
	board.input_enabled = false
	board.coin_finished = false
	board._on_network_action({"type": "coin_finished"})
	check("peer finish waits for local animation", not board.input_enabled)
	board._on_coin_finished()
	check("reverse finish order unlocks", board.input_enabled)
	board.free()
	network.reset()
	var scene = load("res://scenes/rzut_moneta.tscn")
	for seed_value in [17, 934]:
		var host_world := SubViewport.new()
		host_world.own_world_3d = true
		root.add_child(host_world)
		var host = scene.instantiate()
		host_world.add_child(host)
		host.configure(true, true)
		var frames: Array[Dictionary] = []
		var host_results: Array[String] = []
		host.snapshot_ready.connect(func(frame: Dictionary): frames.append(JSON.parse_string(JSON.stringify(frame))))
		host.wyrzucona.connect(func(result: String): host_results.append(result))
		network.coin_peer_ready = false
		host.launch(seed_value)
		check("wait for guest readiness", not host.moneta.rzucona and frames.is_empty())
		network.coin_peer_ready = true
		host.launch(seed_value)
		check("launch has no result", host_results.is_empty() and frames.size() == 1 and frames[0]["result"] == "")
		host.launch(seed_value + 1)
		check("duplicate launch ignored", frames.size() == 1)
		for tick in range(2400):
			await physics_frame
			if host.resolved:
				break
		check("physical throw settles", host.resolved)
		if not host.resolved:
			print("velocity: ", host.moneta.linear_velocity, " spin: ", host.moneta.angular_velocity, " contacts: ", host.moneta.get_contact_count())
			quit(1)
			return
		check("single host result", host_results.size() == 1)
		host.ray_cast_3d.force_raycast_update()
		check("result matches actual face", host_results[0] == ("reszka" if host.ray_cast_3d.is_colliding() else "orzel"))
		var guest_world := SubViewport.new()
		guest_world.own_world_3d = true
		root.add_child(guest_world)
		var guest = scene.instantiate()
		guest_world.add_child(guest)
		guest.configure(false, true)
		guest.set_process(false)
		var guest_results: Array[String] = []
		guest.wyrzucona.connect(func(result: String): guest_results.append(result))
		guest.launch(12)
		check("guest cannot run physics", not guest.moneta.rzucona and guest.moneta.freeze)
		# Deliver landing first, all other packets backwards, withholding frame 1.
		for i in range(frames.size() - 1, -1, -1):
			if i != 1:
				guest.receive_snapshot(frames[i])
		guest._process(100.0)
		check("missing frame stalls result", not guest.resolved and guest.playback_index == 0)
		guest.receive_snapshot(frames[1])
		guest.receive_snapshot(frames[1])
		for i in range(1, frames.size()):
			guest._process(float(frames[i]["time"]) - float(frames[i - 1]["time"]) + 0.000001)
			var p: Array = frames[i]["position"]
			check("replayed trajectory %d" % i, guest.moneta.position.distance_to(Vector3(p[0], p[1], p[2])) < 0.01)
		check("same result once", guest_results == host_results)
		check("same camera", abs(guest.camera_animation.current_animation_position - host.camera_animation.current_animation_position) < 0.001)
		check("same final rotation", abs(guest.moneta.quaternion.dot(host.moneta.quaternion)) > 0.9999)
		guest.receive_snapshot(frames.back())
		guest._process(10.0)
		check("duplicate final ignored", guest_results.size() == 1)
		guest_world.free()
		host_world.free()
		print("Coin seed ", seed_value, ": ", frames.size(), " frames, result ", host_results)
	print("Coin integration failures: ", failures)
	quit(1 if failures else 0)
