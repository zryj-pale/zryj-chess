extends Node2D

@onready var plansza: TileMapLayer = $TileMapLayer

enum Stany { IDLE, GRAB, SELECT, PLACEMENT }
const OKNO = preload("res://scenes/okno_rzutu.tscn")

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
var remote_coin_launch_pending := false
var _prev_mouse_pressed := false

func _ready() -> void:
	add_to_group("game_main")
	generacja_pol(6)
	if NetworkManager.is_online:
		my_color = "b" if NetworkManager.is_host else "c"
		NetworkManager.action_received.connect(_on_network_action)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		ustawienie_z_pozycji(NetworkManager.white_pieces, NetworkManager.black_pieces)
		start_online_match()
	else:
		ustawienie_z_pozycji([], [])
		start_local_match()
	$"dzwiek/muzyka w tle".play()

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
	if remote_coin_launch_pending:
		coin_window.launch()
		remote_coin_launch_pending = false

func _on_coin_throw_started() -> void:
	if NetworkManager.is_online and NetworkManager.is_host:
		NetworkManager.submit_action({"type": "coin_launch"})

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
	_prev_mouse_pressed = pressed

func stan_idle(_pole: Vector2i, pressed: bool) -> void:
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
		stan = Stany.IDLE
	else:
		$dzwiek/zakaz.play()
		wybrana = null
		stan = Stany.IDLE
	chwycona = null

func stan_select(pole: Vector2i, pressed: bool) -> void:
	if not pressed or _prev_mouse_pressed:
		return
	var figura = najechana_figura()
	if figura and figura.kolor == kolor_posuniecia:
		if figura == wybrana:
			_begin_grab(figura)
		else:
			wybrana = figura
		return
	if not ruch(wybrana, pole):
		wybrana = null
		$dzwiek/zakaz.play()
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

func ruch(figura, cel: Vector2i, from_network := false) -> bool:
	if not figura or game_finished or figura.kolor != kolor_posuniecia:
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
	$dzwiek/ruch.play()
	koniec_tury()
	if czy_szach(kolor_posuniecia):
		$dzwiek/szach.play()
		if not GameRules.has_legal_move(_rules_pieces(), dostepne_pola, kolor_posuniecia):
			koniec_gry(GameRules.other_color(kolor_posuniecia))
	elif not GameRules.has_legal_move(_rules_pieces(), dostepne_pola, kolor_posuniecia):
		koniec_gry()

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
				if coin_window:
					coin_window.launch()
				else:
					remote_coin_launch_pending = true
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
	return GameRules.is_legal_move(pieces, dostepne_pola, index, cel)

func czy_szach(kolor: String) -> bool:
	return GameRules.is_in_check(_rules_pieces(), dostepne_pola, kolor)

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

func koniec_tury() -> void:
	kolor_posuniecia = GameRules.other_color(kolor_posuniecia)

func moze_promowac(figura) -> bool:
	return figura.typ == "P" and ((figura.kolor == "b" and pozycja(figura).y == 1) or (figura.kolor == "c" and pozycja(figura).y == 6))

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
