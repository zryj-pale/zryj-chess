extends SceneTree

var failures := 0

func _init() -> void:
	run.call_deferred()

func check(label: String, value: bool) -> void:
	if not value:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	var profile = root.get_node("PozycjaOsobista")
	profile.local_sandbox = true
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	if "--render" in OS.get_cmdline_user_args():
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/sandbox_preview.png")
		game.sandbox_ui.collection.popup_centered(Vector2i(460, 360))
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/sandbox_cards_preview.png")
		game.sandbox_ui.collection.hide()
	check("sandbox starts without loadout or coin", game.sandbox and game.input_enabled and game.coin_window == null)
	check("mode hand-off consumed", not profile.local_sandbox)
	game.dodaj("P", "b", Vector2i(2, 2))
	game.dodaj("K", "c", Vector2i(4, 4))
	var pawn = game.stoi_figura(Vector2i(2, 2))
	check("free move ignores chess geometry", game.ruch(pawn, Vector2i(4, 4)))
	check("king capture does not end sandbox", not game.game_finished and game.figury.size() == 1)
	game.dodaj("W", "c", Vector2i(1, 1))
	check("other side moves immediately", game.ruch(game.stoi_figura(Vector2i(1, 1)), Vector2i(3, 3)))
	for i in range(5):
		game._apply_hole(Vector2i(5, 5))
		game._apply_tile(Vector2i(5, 5))
	check("unlimited reusable resources", game.bialy_tiles == 2 and game.czarny_tiles == 2 and game.bialy_holes == 0 and game.czarny_holes == 0 and Vector2i(5, 5) not in game.holes)
	game.sandbox_set_card("b", "omni_pawns", true)
	game.sandbox_set_card("b", "double_step_pawns", true)
	check("several cards coexist", CardHooks.pawns_move_omnidirectionally(game.active_cards) and CardHooks.pawns_can_double_step(game.active_cards))
	game.sandbox_rules = true
	check("card allows sideways two-step", game.ruch(pawn, Vector2i(6, 4)))
	game.sandbox_set_card("b", "omni_pawns", false)
	check("disabling card changes movement immediately", not game.ruch(pawn, Vector2i(4, 4)))
	game.sandbox_set_card("c", "board_10x10", true)
	check("board expands live", game.pole_w_granicach(Vector2i(-1, 8)))
	game.sandbox_set_card("c", "board_10x10", false)
	check("board bounds revert live", not game.pole_w_granicach(Vector2i(-1, 8)))
	game.sandbox_set_card("b", "duck_chess", true)
	game._apply_duck(Vector2i(1, 2))
	game.sandbox_set_card("b", "duck_chess", false)
	check("duck removed on disabling card", not game.duck_marker.visible)
	game.koniec_gry("b")
	check("sandbox never declares winner", not game.game_finished)
	game.sandbox_remove_at(Vector2i(3, 3))
	check("sandbox deletion removes figure", game.stoi_figura(Vector2i(3, 3)) == null)
	game.queue_free()
	await process_frame
	var versus = load("res://scenes/main.tscn").instantiate()
	root.add_child(versus)
	versus.set_process(false)
	check("next match is ordinary versus", not versus.sandbox and not versus.input_enabled)
	versus.dodaj("P", "c", Vector2i(2, 2))
	check("versus still enforces turn", not versus.ruch(versus.stoi_figura(Vector2i(2, 2)), Vector2i(2, 3)))
	versus._apply_tile(Vector2i(0, 0))
	check("versus still consumes resources", versus.bialy_tiles == 1)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	versus._unhandled_input(right_click)
	versus.sandbox_remove_at(Vector2i(2, 2))
	check("right click cannot delete in versus", versus.figury.size() == 1)
	versus.queue_free()
	await process_frame
	profile.ustawienie = [["P", Vector2i(2, 4)]]
	var setup = load("res://scenes/ustawianie.tscn").instantiate()
	root.add_child(setup)
	setup.usun_figure(setup.stoi_figura(Vector2i(2, 4)))
	check("setup deletion updates army and points", setup.figury.is_empty() and profile.ustawienie.is_empty() and setup.oblicz_punkty() == 0)
	setup.queue_free()
	await process_frame
	profile.set_skip_intro(true)
	profile.skip_intro = false
	profile._load_profile()
	check("skip intro persists", profile.skip_intro)
	var menu = load("res://scenes/menu glowne.tscn").instantiate()
	root.add_child(menu)
	check("intro hidden on menu entry", not menu.get_node("VideoStreamPlayer").visible and not menu.get_node("IntroBackdrop").visible)
	menu.queue_free()
	await process_frame
	print("Sandbox integration: ", failures, " failures")
	quit(1 if failures else 0)
