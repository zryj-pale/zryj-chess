extends Node2D

@onready var plansza: TileMapLayer = $TileMapLayer

enum Stany { IDLE, GRAB, SELECT, PLACEMENT, DUCK }
const OKNO = preload("res://scenes/okno_rzutu.tscn")
const DUCK_TEXTURE = preload("res://assets/duck.png")
const MAIN_MENU_BACKGROUND = preload("res://scenes/tlo_ekranu_glownego.tscn")
const MATERIAL_VALUES := {"P": 1, "S": 2, "G": 2, "W": 4, "H": 6, "K": 6}

var stan := Stany.IDLE
var figury: Array = []
var dostepne_pola: Array[Vector2i] = []
var chwycona = null
var wybrana = null
var poczatkowe_pole := Vector2i.ZERO
var kolor_posuniecia := "b"
var my_color := ""
var bialy_tiles := 2
var czarny_tiles := 2
var game_finished := false
var input_enabled := false
var coin_window = null
var remote_coin_launch_seed := -1
var _prev_mouse_pressed := false
var active_cards := {"b": "", "c": ""}
var duck_position := Vector2i(-99, -99)
var duck_pending := false
var duck_marker: Sprite2D
var match_background = null
var player_nicknames := {"b": "", "c": ""}
var player_colors := {"b": Color.WHITE, "c": Color.WHITE}

func _ready() -> void:
	add_to_group("game_main")
	_add_menu_background()
	generacja_pol(6)
	if NetworkManager.is_online:
		my_color = "b" if NetworkManager.is_host else "c"
		active_cards = {"b": NetworkManager.white_card, "c": NetworkManager.black_card}
		player_nicknames = {"b": NetworkManager.white_nickname, "c": NetworkManager.black_nickname}
		NetworkManager.action_received.connect(_on_network_action)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		ustawienie_z_pozycji(NetworkManager.white_pieces, NetworkManager.black_pieces)
		start_online_match()
	else:
		active_cards = {"b": PozycjaOsobista.wybrana_karta, "c": PozycjaOsobista.wybrana_karta}
		player_nicknames = {"b": PozycjaOsobista.nickname, "c": PozycjaOsobista.nickname}
		ustawienie_z_pozycji([], [])
		start_local_match()
	$"dzwiek/muzyka w tle".play()
	_create_duck_marker()
	_refresh_player_colors()
	_refresh_background_tint()

func _add_menu_background() -> void:
	match_background = MAIN_MENU_BACKGROUND.instantiate()
	# The source scene uses positive local z-indices, so place its root well
	# behind the board, pieces and HUD while retaining its menu animation.
	match_background.z_index = -10
	add_child(match_background)

func _refresh_player_colors() -> void:
	player_colors = {
		"b": PozycjaOsobista.nickname_color(str(player_nicknames.get("b", ""))),
		"c": PozycjaOsobista.nickname_color(str(player_nicknames.get("c", "")))
	}

func _refresh_background_tint() -> void:
	if not match_background:
		return
	var white_points := _material_points("b")
	var black_points := _material_points("c")
	var total := white_points + black_points
	var black_weight := 0.5 if total == 0 else float(black_points) / float(total)
	var tint: Color = player_colors["b"].lerp(player_colors["c"], black_weight)
	match_background.set_match_tint(tint)

func _material_points(color: String) -> int:
	var total := 0
	for figura in figury:
		if figura.kolor == color:
			total += int(MATERIAL_VALUES.get(str(figura.typ), 0))
	return total

func ustawienie_z_pozycji(white: Array, black: Array) -> void:
	if NetworkManager.is_online:
		for piece in white:
			dodaj(str(piece[0]), "b", Vector2i(int(piece[1]), int(piece[2])))
		for piece in black:
			dodaj(str(piece[0]), "c", Vector2i(int(piece[1]), int(piece[2])))
		return
	for piece in PozycjaOsobista.ustawienie:
		dodaj(str(piece[0]), "b", piece[1])
		dodaj(str(piece[0]), "c", Vector2i(piece[1].x, 7 - piece[1].y))

func start_local_match() -> void:
	var coin_result := "orzel" if randf() < 0.5 else "reszka"
	kolor_posuniecia = GameRules.starting_turn(_wire_pieces("b"), _wire_pieces("c"), coin_result)
	_show_coin(coin_result, true)

func start_online_match() -> void:
	kolor_posuniecia = NetworkManager.initial_turn
	_show_coin(NetworkManager.coin_result, NetworkManager.is_host)

func _show_coin(result: String, can_launch: bool) -> void:
	coin_window = OKNO.instantiate()
	coin_window.configure(result, can_launch)
	coin_window.throw_started.connect(_on_coin_throw_started)
	coin_window.koniec_rzutu.connect(_on_coin_finished)
	add_child(coin_window)
	if remote_coin_launch_seed >= 0:
		coin_window.launch(remote_coin_launch_seed)
		remote_coin_launch_seed = -1

func _on_coin_throw_started(throw_seed: int) -> void:
	if NetworkManager.is_online and NetworkManager.is_host:
		NetworkManager.submit_action({"type": "coin_launch", "seed": throw_seed})

func _on_coin_finished() -> void:
	input_enabled = true
	coin_window = null
	if czy_szach(kolor_posuniecia):
		$dzwiek/szach.play()

func _process(_delta: float) -> void:
	if game_finished or not input_enabled:
		return
	var pole := plansza.local_to_map(get_global_mouse_position())
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	match stan:
		Stany.IDLE: stan_idle(pole, pressed)
		Stany.GRAB: stan_grab(pole, pressed)
		Stany.SELECT: stan_select(pole, pressed)
		Stany.PLACEMENT: stan_placement(pole, pressed)
		Stany.DUCK: stan_duck(pole, pressed)
	_prev_mouse_pressed = pressed

func stan_idle(_pole: Vector2i, pressed: bool) -> void:
	if duck_pending:
		stan = Stany.DUCK
		return
	if NetworkManager.is_online and kolor_posuniecia != my_color:
		return
	if Input.is_action_just_pressed("space"):
		var tiles_left := bialy_tiles if kolor_posuniecia == "b" else czarny_tiles
		if tiles_left > 0:
			stan = Stany.PLACEMENT
			return
	if pressed and not _prev_mouse_pressed:
		var figura = najechana_figura()
		if figura and figura.kolor == kolor_posuniecia:
			_begin_grab(figura)

func _begin_grab(figura) -> void:
	chwycona = figura
	poczatkowe_pole = pozycja(figura)
	figura.top_level = true
	stan = Stany.GRAB

func stan_grab(pole: Vector2i, pressed: bool) -> void:
	if pressed:
		chwycona.global_position = get_global_mouse_position()
		return
	# Restore before taking a rules snapshot; dragged pixels must never affect chess logic.
	chwycona.global_position = plansza.map_to_local(poczatkowe_pole)
	chwycona.top_level = false
	if pole == poczatkowe_pole:
		wybrana = chwycona
		stan = Stany.SELECT
	elif ruch(chwycona, pole):
		if not duck_pending:
			stan = Stany.IDLE
	else:
		$dzwiek/zakaz.play()
		wybrana = null
		if not duck_pending:
			stan = Stany.IDLE
	chwycona = null

func stan_select(pole: Vector2i, pressed: bool) -> void:
	if not pressed or _prev_mouse_pressed:
		return
	var figura = najechana_figura()
	if figura and figura.kolor == kolor_posuniecia:
		_begin_grab(figura)
		return
	if not ruch(wybrana, pole):
		wybrana = null
		$dzwiek/zakaz.play()
	if not duck_pending:
		stan = Stany.IDLE

func stan_placement(pole: Vector2i, pressed: bool) -> void:
	if Input.is_action_just_pressed("space"):
		stan = Stany.IDLE
		return
	if pressed and not _prev_mouse_pressed:
		if not pole_na_planszy(pole) and pole_w_granicach(pole):
			_apply_tile(pole)
			if NetworkManager.is_online:
				NetworkManager.submit_action({"type": "tile", "x": pole.x, "y": pole.y})
			$dzwiek/ruch.play()
		else:
			$dzwiek/zakaz.play()
		stan = Stany.IDLE

func stan_duck(pole: Vector2i, pressed: bool) -> void:
	if NetworkManager.is_online and kolor_posuniecia != my_color:
		return
	if pressed and not _prev_mouse_pressed:
		if _can_place_duck(pole):
			if NetworkManager.is_online:
				NetworkManager.submit_action({"type": "duck", "x": pole.x, "y": pole.y})
			_apply_duck(pole)
			_finish_after_move(kolor_posuniecia)
		else:
			$dzwiek/zakaz.play()

func ruch(figura, cel: Vector2i, from_network := false) -> bool:
	if not figura or game_finished or duck_pending or figura.kolor != kolor_posuniecia:
		return false
	if not from_network and NetworkManager.is_online and figura.kolor != my_color:
		return false
	var start := pozycja(figura)
	if not moze_ruszyc(figura, cel):
		return false
	if not from_network and NetworkManager.is_online:
		NetworkManager.submit_action({"type": "move", "from_x": start.x, "from_y": start.y, "to_x": cel.x, "to_y": cel.y})
	_apply_move(figura, cel)
	return true

func _apply_move(figura, cel: Vector2i) -> void:
	var captured = stoi_figura(cel)
	if captured:
		zbicie(captured)
	figura.global_position = plansza.map_to_local(cel)
	if moze_promowac(figura):
		figura.promocja("H")
	_refresh_background_tint()
	$dzwiek/ruch.play()
	var mover := kolor_posuniecia
	var winner := CardHooks.win_condition_winner(active_cards, _rules_pieces(), dostepne_pola, mover)
	if not winner.is_empty():
		koniec_gry(winner)
		return
	if CardHooks.needs_extra_step_after_move(active_cards):
		duck_pending = true
		stan = Stany.DUCK
		return
	_finish_after_move(mover)

func _finish_after_move(mover: String) -> void:
	duck_pending = false
	stan = Stany.IDLE
	var move_effects := CardHooks.after_move(active_cards, mover, {
		"pieces": _rules_pieces(),
		"board": dostepne_pola,
		"duck_position": duck_position,
	})
	match str(move_effects["grant_tile_to"]):
		"b": bialy_tiles += 1
		"c": czarny_tiles += 1
	koniec_tury()
	if czy_szach(kolor_posuniecia):
		$dzwiek/szach.play()
		if not GameRules.has_legal_move(_rules_pieces(), dostepne_pola, kolor_posuniecia, active_cards, duck_position):
			koniec_gry(GameRules.other_color(kolor_posuniecia))
	elif not GameRules.has_legal_move(_rules_pieces(), dostepne_pola, kolor_posuniecia, active_cards, duck_position):
		koniec_gry(CardHooks.stalemate_winner(active_cards, kolor_posuniecia))

func _apply_tile(pole: Vector2i) -> void:
	dodaj_pole(pole)
	if kolor_posuniecia == "b":
		bialy_tiles -= 1
	else:
		czarny_tiles -= 1

func _on_network_action(action: Dictionary) -> void:
	match action.get("type", ""):
		"coin_launch":
			if not NetworkManager.is_host:
				var throw_seed := int(action.get("seed", -1))
				if throw_seed < 0:
					return
				if coin_window:
					coin_window.launch(throw_seed)
				else:
					remote_coin_launch_seed = throw_seed
		"move":
			var from := Vector2i(int(action.get("from_x", -99)), int(action.get("from_y", -99)))
			var to := Vector2i(int(action.get("to_x", -99)), int(action.get("to_y", -99)))
			var figura = stoi_figura(from)
			if figura and figura.kolor != my_color:
				ruch(figura, to, true)
		"tile":
			var pole := Vector2i(int(action.get("x", -99)), int(action.get("y", -99)))
			if kolor_posuniecia != my_color and not pole_na_planszy(pole) and pole_w_granicach(pole):
				_apply_tile(pole)
		"duck":
			var duck_target := Vector2i(int(action.get("x", -99)), int(action.get("y", -99)))
			if kolor_posuniecia != my_color and duck_pending and _can_place_duck(duck_target):
				_apply_duck(duck_target)
				_finish_after_move(kolor_posuniecia)
		"game_over":
			koniec_gry(str(action.get("winner", "")), true)

func _on_player_disconnected(_reason: String) -> void:
	if not game_finished:
		game_finished = true
		NetworkManager.reset()
		get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

func moze_ruszyc(figura, cel: Vector2i) -> bool:
	var pieces := _rules_pieces()
	var index := GameRules.piece_index_at(pieces, pozycja(figura))
	return GameRules.is_legal_move(pieces, dostepne_pola, index, cel, active_cards, duck_position)

func czy_szach(kolor: String) -> bool:
	return GameRules.is_in_check(_rules_pieces(), dostepne_pola, kolor, active_cards, duck_position)

func _rules_pieces() -> Array:
	var result: Array = []
	for figura in figury:
		result.append({"type": str(figura.typ), "color": str(figura.kolor), "x": pozycja(figura).x, "y": pozycja(figura).y})
	return result

func _wire_pieces(color: String) -> Array:
	var result: Array = []
	for figura in figury:
		if figura.kolor == color:
			var pole := pozycja(figura)
			result.append([figura.typ, pole.x, pole.y])
	return result

func najechana_figura():
	for figura in figury:
		if figura.mysz:
			return figura
	return null

func stoi_figura(pole: Vector2i):
	for figura in figury:
		if pozycja(figura) == pole:
			return figura
	return null

func pozycja(figura) -> Vector2i:
	return plansza.local_to_map(figura.global_position)

func dodaj(typ: String, kolor: String, pole: Vector2i) -> void:
	if not pole_na_planszy(pole) or stoi_figura(pole):
		return
	var figura = preload("res://scenes/figura.tscn").instantiate()
	figura.typ = typ
	figura.kolor = kolor
	add_child(figura)
	figury.append(figura)
	figura.global_position = plansza.map_to_local(pole)

func zbicie(figura) -> void:
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zbicie.play()

func generacja_pol(rozmiar: int) -> void:
	for x in range(1, rozmiar + 1):
		for y in range(1, rozmiar + 1):
			dostepne_pola.append(Vector2i(x, y))

func pole_w_granicach(pole: Vector2i) -> bool:
	return pole.x >= 0 and pole.x <= 7 and pole.y >= 0 and pole.y <= 7

func pole_na_planszy(pole: Vector2i) -> bool:
	return pole in dostepne_pola

func dodaj_pole(pole: Vector2i) -> void:
	if not pole_w_granicach(pole) or pole_na_planszy(pole):
		return
	plansza.set_cell(pole, 0, pole)
	dostepne_pola.append(pole)

func _create_duck_marker() -> void:
	duck_marker = Sprite2D.new()
	duck_marker.texture = DUCK_TEXTURE
	duck_marker.scale = Vector2(0.28, 0.28)
	duck_marker.position = Vector2(-999, -999)
	add_child(duck_marker)

func _can_place_duck(pole: Vector2i) -> bool:
	return pole_na_planszy(pole) and pole != duck_position and stoi_figura(pole) == null and not GameRules.is_in_check(_rules_pieces(), dostepne_pola, kolor_posuniecia, active_cards, pole)

func _apply_duck(pole: Vector2i) -> void:
	duck_position = pole
	duck_marker.position = plansza.map_to_local(pole)
	$dzwiek/ruch.play()

func koniec_tury() -> void:
	kolor_posuniecia = GameRules.other_color(kolor_posuniecia)

func moze_promowac(figura) -> bool:
	if figura.typ != "P" or dostepne_pola.is_empty():
		return false
	return pozycja(figura).y == GameRules.edge_row(dostepne_pola, figura.kolor)

func koniec_gry(kolor_wygranej := "", from_network := false) -> void:
	if game_finished:
		return
	game_finished = true
	if NetworkManager.is_online:
		if not from_network:
			NetworkManager.submit_action({"type": "game_over", "winner": kolor_wygranej})
		if NetworkManager.is_host:
			NetworkManager.close_room()
		else:
			NetworkManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
