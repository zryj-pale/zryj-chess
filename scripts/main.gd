extends Node2D

# The board is 3D content, but everything else in this scene (HUD, the
# animated menu background, the promotion/loadout pickers) is plain 2D and
# needs to stay layerable with z_index the normal way - 2D CanvasItems always
# draw on top of ANY 3D World content in a shared viewport, with no way to
# put one "behind" the other. So the 3D board lives inside its own
# SubViewport, displayed through a fullscreen SubViewportContainer, which is
# itself just an ordinary CanvasItem the 2D background/HUD can layer against.
@onready var board_container: SubViewportContainer = $BoardViewportContainer
@onready var board_viewport: SubViewport = $BoardViewportContainer/BoardViewport
@onready var board_root: Node3D = $BoardViewportContainer/BoardViewport/BoardRoot
@onready var camera_rig: Node3D = $BoardViewportContainer/BoardViewport/CameraRig
@onready var camera: Camera3D = $BoardViewportContainer/BoardViewport/CameraRig/Camera3D

const TILE_SIZE_3D := 1.0
const PIECE_Y := TILE_SIZE_3D * 0.5 # lifts pieces/marker so they stand on the tile plane instead of poking through it
const PIECE_HEIGHT := TILE_SIZE_3D # a billboard piece is one tile tall; the camera has to keep its top in frame too
const CAMERA_TILT_DEG := 55.0 # degrees down from horizontal - the "old 3D game" angled look
const CAMERA_MIN_DISTANCE := 1.0
const CAMERA_FRAMING_MARGIN := 1.05 # extra breathing room so the board doesn't touch the viewport edges
const INVALID_POLE := Vector2i(-9999, -9999)

enum Stany { IDLE, GRAB, SELECT, PLACEMENT, DUCK, PROMOTION, HOLE_PLACEMENT }
const OKNO = preload("res://scenes/okno_rzutu.tscn")
const DUCK_TEXTURE = preload("res://assets/duck.png")
const MAIN_MENU_BACKGROUND = preload("res://scenes/tlo_ekranu_glownego.tscn")
const MATERIAL_VALUES := {"P": 1, "S": 2, "G": 2, "W": 4, "H": 6, "K": 6}
const PROMOTION_CHOICES := ["H", "W", "G", "S"]
const PROMOTION_LABELS := {"H": "Hetman", "W": "Wieża", "G": "Goniec", "S": "Skoczek"}
const CREAM_COLOR := Color8(255, 228, 196)
const DARK_COLOR := Color8(0, 40, 10)
# Green would be the chess convention, but the board's own dark squares are
# green - these have to stay legible on BOTH the cream and the dark tile.
const MOVE_HINT_COLOR := Color(0.2, 0.62, 1.0, 0.62)
const CAPTURE_HINT_COLOR := Color(1.0, 0.25, 0.2, 0.66)
const PLACE_HINT_COLOR := Color(1.0, 0.82, 0.2, 0.6)
const HINT_Y := 0.02 # a hair above the tile plane, so the quad wins the depth test
const HINT_SIZE := 0.88 # slightly inset, so neighbouring hints stay visually separate
const HINT_KEY_STALE := "!stale" # sentinel _hint_signature() can never return

var stan := Stany.IDLE
var figury: Array = []
var dostepne_pola: Array[Vector2i] = []
var tiles: Dictionary = {} # Vector2i -> MeshInstance3D, mirrors dostepne_pola visually
var cream_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var move_hint_material: StandardMaterial3D
var capture_hint_material: StandardMaterial3D
var place_hint_material: StandardMaterial3D
var hints: Array[MeshInstance3D] = []
# What the currently drawn hints describe. Recomputing legal targets means
# running the rules engine once per candidate square, so it only happens when
# this changes - not every frame.
var _hint_key := ""
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
var duck_marker: Sprite3D
var promotion_pending := false
var promotion_figure = null
var promotion_picker: Control
var match_background = null
var player_nicknames := {"b": "", "c": ""}
var player_colors := {"b": Color.WHITE, "c": Color.WHITE}
var board_flipped := false
var white_loadout_choice := 0
var black_loadout_choice := 0
var board_min := 0 # 0..7 by default; board_10x10 widens this to -1..8
var board_max := 7
var bialy_holes := 0
var czarny_holes := 0
var holes: Array[Vector2i] = []

func _ready() -> void:
	add_to_group("game_main")
	_add_menu_background()
	_init_tile_materials()
	generacja_pol(6)
	_on_window_resized()
	get_viewport().size_changed.connect(_on_window_resized)
	_create_duck_marker()
	_create_promotion_picker()
	get_viewport().size_changed.connect(func(): _center_screen_control(promotion_picker, Vector2(300, 70)))
	$"dzwiek/muzyka w tle".play()
	if NetworkManager.is_online:
		my_color = "b" if NetworkManager.is_host else "c"
		# White already renders with its home rows at the bottom by default;
		# only the guest (black) needs its own view mirrored so its own side
		# is always at the bottom of ITS screen. Local play (my_color == "")
		# is shared by both players on one screen, so it never flips.
		board_flipped = my_color == "c"
		active_cards = {"b": NetworkManager.white_card, "c": NetworkManager.black_card}
		player_nicknames = {"b": NetworkManager.white_nickname, "c": NetworkManager.black_nickname}
		_apply_active_cards_setup()
		NetworkManager.action_received.connect(_on_network_action)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		ustawienie_z_pozycji(NetworkManager.white_pieces, NetworkManager.black_pieces)
		_refresh_player_colors()
		_refresh_background_tint()
		start_online_match()
	else:
		_show_loadout_picker()

# Board size (board_10x10) and hole allowance (board_hole) depend on which
# cards are active, so this only runs once active_cards is actually known -
# right away for online, or once the local loadout picker's choice is made.
func _apply_active_cards_setup() -> void:
	board_min = CardHooks.board_min(active_cards)
	board_max = CardHooks.board_max(active_cards)
	_center_camera()
	bialy_holes = CardHooks.starting_holes(active_cards, "b")
	czarny_holes = CardHooks.starting_holes(active_cards, "c")

# Anchor percentages (0.5 = center) only resolve correctly once a Control is
# actually inside the tree with a settled size - for one built and added at
# runtime (the loadout and promotion pickers) that can be stale/wrong on the
# first frame, same class of problem control.gd already works around for the
# coin-toss overlay. Sidestep it entirely: leave anchors at their 0 default
# and set position/size directly from the actual viewport rect.
func _center_screen_control(control: Control, size: Vector2) -> void:
	control.size = size
	control.position = ((get_viewport_rect().size - size) / 2.0).round()

# A Control parented to a Node2D anchors against an EMPTY rect, so "full
# rect" anchors silently collapse the container to 0x0 and none of the board
# is ever drawn - the same trap _center_screen_control() works around for the
# runtime-built pickers. Size the container by hand instead; its `stretch`
# then keeps the SubViewport (and with it the Camera3D's aspect ratio and
# ray-casts) matched to the real window 1:1, so mouse-position math done in
# the outer 2D viewport maps straight onto the board.
func _on_window_resized() -> void:
	board_container.position = Vector2.ZERO
	board_container.size = get_viewport_rect().size
	_center_camera()

func _init_tile_materials() -> void:
	cream_material = StandardMaterial3D.new()
	cream_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cream_material.albedo_color = CREAM_COLOR
	dark_material = StandardMaterial3D.new()
	dark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_material.albedo_color = DARK_COLOR
	move_hint_material = _hint_material(MOVE_HINT_COLOR)
	capture_hint_material = _hint_material(CAPTURE_HINT_COLOR)
	place_hint_material = _hint_material(PLACE_HINT_COLOR)

func _hint_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

# Frames the camera so the whole active board (span ranges 8..10 depending on
# board_10x10) fits inside the viewport, and rotates it 180 degrees for the
# flipped (guest) view instead of mirroring every board coordinate the way
# the old 2D _view() helper used to.
func _center_camera() -> void:
	var center := (board_min + board_max) / 2.0
	camera_rig.position = Vector3(center, 0.0, center) * TILE_SIZE_3D
	camera_rig.rotation = Vector3(0.0, PI if board_flipped else 0.0, 0.0)
	var half := (board_max - board_min + 1) * TILE_SIZE_3D * 0.5
	_place_camera(half, half)

# Pulls the camera back along its fixed tilt until every corner of the board
# - and the top of a piece standing on it - is inside the frustum. The
# distance is solved per corner rather than measured from the camera's
# ground footprint: for a tilted perspective camera that footprint is a
# trapezoid running off toward the horizon, so its bounding box claims a far
# larger view than the part of it the board can actually use.
func _place_camera(half_x: float, half_z: float) -> void:
	var tilt := deg_to_rad(CAMERA_TILT_DEG)
	var viewport_size := Vector2(board_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	# Camera3D keeps the vertical FOV by default, so the horizontal
	# half-angle is the one derived from the aspect ratio.
	var tan_v := tan(deg_to_rad(camera.fov) * 0.5) / CAMERA_FRAMING_MARGIN
	var tan_h := tan_v * (viewport_size.x / viewport_size.y)
	var distance := CAMERA_MIN_DISTANCE
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for corner_y in [0.0, PIECE_HEIGHT]:
				# The corner expressed along the camera's own axes, with the
				# camera still sitting on the pivot: backing it off by
				# `distance` then simply adds `distance` to the depth, which
				# turns each fit condition into a one-line solve for it.
				var corner := Vector3(sx * half_x, corner_y, sz * half_z)
				var right := corner.x
				var up := corner.y * cos(tilt) - corner.z * sin(tilt)
				var depth := corner.y * sin(tilt) + corner.z * cos(tilt)
				distance = maxf(distance, depth + absf(right) / tan_h)
				distance = maxf(distance, depth + absf(up) / tan_v)
	camera.position = Vector3(0.0, sin(tilt), cos(tilt)) * distance
	camera.rotation = Vector3(-tilt, 0.0, 0.0)

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
	for piece in white:
		dodaj(str(piece[0]), "b", Vector2i(int(piece[1]), int(piece[2])))
	for piece in black:
		dodaj(str(piece[0]), "c", Vector2i(int(piece[1]), int(piece[2])))

# Local versus lets white and black each pick which of the two saved
# loadouts (army + card) they play with, before the coin toss. Online skips
# this entirely and always uses loadouts[0] (see lobby.gd), since there's
# only one of you connecting - nothing to choose between.
func _show_loadout_picker() -> void:
	# menu_glowne.gd already refuses to reach local play unless at least one
	# loadout has a king, so this is never -1 in practice.
	var default_index := 0 if PozycjaOsobista.loadout_has_king(0) else 1
	white_loadout_choice = default_index
	black_loadout_choice = default_index
	var picker := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	picker.add_child(vbox)
	var title := Label.new()
	title.text = "Wybierzcie loadouty przed rzutem monetą"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	var white_buttons: Array[Button] = []
	var black_buttons: Array[Button] = []
	vbox.add_child(_build_loadout_row("Białe:", white_buttons, 0))
	vbox.add_child(_build_loadout_row("Czarne:", black_buttons, 1))
	var start_button := Button.new()
	start_button.text = "Rozpocznij mecz"
	start_button.pressed.connect(func():
		picker.queue_free()
		_begin_local_match(white_loadout_choice, black_loadout_choice)
	)
	vbox.add_child(start_button)
	add_child(picker)
	_center_screen_control(picker, Vector2(340, 190))

func _build_loadout_row(label_text: String, buttons_out: Array[Button], which: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(50, 0)
	row.add_child(label)
	var current_choice := white_loadout_choice if which == 0 else black_loadout_choice
	for i in range(PozycjaOsobista.loadouts.size()):
		var button := Button.new()
		button.text = "Loadout %d" % (i + 1)
		button.toggle_mode = true
		button.button_pressed = i == current_choice
		# A loadout without a king can't field a playable side, so it can't
		# be picked for either color.
		button.disabled = not PozycjaOsobista.loadout_has_king(i)
		button.pressed.connect(_on_loadout_choice_pressed.bind(which, i, buttons_out))
		row.add_child(button)
		buttons_out.append(button)
	return row

func _on_loadout_choice_pressed(which: int, index: int, buttons: Array[Button]) -> void:
	if which == 0:
		white_loadout_choice = index
	else:
		black_loadout_choice = index
	for i in range(buttons.size()):
		buttons[i].button_pressed = i == index

func _begin_local_match(white_index: int, black_index: int) -> void:
	var white_loadout: Dictionary = PozycjaOsobista.loadouts[white_index]
	var black_loadout: Dictionary = PozycjaOsobista.loadouts[black_index]
	active_cards = {"b": str(white_loadout.get("karta", "")), "c": str(black_loadout.get("karta", ""))}
	player_nicknames = {"b": PozycjaOsobista.nickname, "c": PozycjaOsobista.nickname}
	_apply_active_cards_setup()
	for piece in white_loadout.get("ustawienie", []):
		dodaj(str(piece[0]), "b", piece[1])
	for piece in black_loadout.get("ustawienie", []):
		dodaj(str(piece[0]), "c", Vector2i(piece[1].x, 7 - piece[1].y))
	_refresh_player_colors()
	_refresh_background_tint()
	start_local_match()

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
	# Board input is polled from Input directly rather than read off events,
	# so the settings overlay swallowing GUI clicks isn't enough - it has to
	# be checked explicitly. A piece held mid-drag when the panel opens is
	# put back on its own square instead of being left floating.
	if Ustawienia.is_open():
		if stan == Stany.GRAB:
			_cancel_grab()
		_update_hints()
		return
	if game_finished:
		_update_hints()
		return
	if not input_enabled:
		_update_hints()
		return
	var pole := _pole_pod_myszka()
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	match stan:
		Stany.IDLE: stan_idle(pole, pressed)
		Stany.GRAB: stan_grab(pole, pressed)
		Stany.SELECT: stan_select(pole, pressed)
		Stany.PLACEMENT: stan_placement(pole, pressed)
		Stany.DUCK: stan_duck(pole, pressed)
		Stany.HOLE_PLACEMENT: stan_hole_placement(pole, pressed)
	_prev_mouse_pressed = pressed
	_update_hints()

func _cancel_grab() -> void:
	if chwycona:
		chwycona.position = _piece_position(poczatkowe_pole)
	chwycona = null
	wybrana = null
	stan = Stany.IDLE

# Called from the settings overlay. Online this is a surrender rather than a
# silent disconnect: the opponent is told they won, so they get the normal
# result screen instead of waiting for a move that will never come. Locally
# there is no winner to declare, so it just drops back to the menu.
func opusc_mecz() -> void:
	if game_finished:
		return
	if NetworkManager.is_online and not my_color.is_empty():
		koniec_gry(GameRules.other_color(my_color))
		return
	game_finished = true
	if NetworkManager.is_online:
		NetworkManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

func stan_idle(pole: Vector2i, pressed: bool) -> void:
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
	if Input.is_action_just_pressed("hole"):
		var holes_left := bialy_holes if kolor_posuniecia == "b" else czarny_holes
		if holes_left > 0:
			stan = Stany.HOLE_PLACEMENT
			return
	if pressed and not _prev_mouse_pressed:
		var figura = stoi_figura(pole)
		if figura and figura.kolor == kolor_posuniecia:
			_begin_grab(figura)

func _begin_grab(figura) -> void:
	chwycona = figura
	poczatkowe_pole = pozycja(figura)
	stan = Stany.GRAB

func stan_grab(pole: Vector2i, pressed: bool) -> void:
	if pressed:
		var hit = _mouse_ground_point()
		if hit != null:
			chwycona.position = hit + Vector3(0.0, PIECE_Y, 0.0)
		return
	# Restore before taking a rules snapshot; dragged pixels must never affect chess logic.
	chwycona.position = _piece_position(poczatkowe_pole)
	if pole == poczatkowe_pole:
		wybrana = chwycona
		stan = Stany.SELECT
	elif ruch(chwycona, pole):
		if not duck_pending and not promotion_pending:
			stan = Stany.IDLE
	else:
		$dzwiek/zakaz.play()
		wybrana = null
		if not duck_pending and not promotion_pending:
			stan = Stany.IDLE
	chwycona = null

func stan_select(pole: Vector2i, pressed: bool) -> void:
	if not pressed or _prev_mouse_pressed:
		return
	var figura = stoi_figura(pole)
	if figura and figura.kolor == kolor_posuniecia:
		_begin_grab(figura)
		return
	if not ruch(wybrana, pole):
		wybrana = null
		$dzwiek/zakaz.play()
	if not duck_pending and not promotion_pending:
		stan = Stany.IDLE

func stan_placement(pole: Vector2i, pressed: bool) -> void:
	if Input.is_action_just_pressed("space"):
		stan = Stany.IDLE
		return
	if pressed and not _prev_mouse_pressed:
		if not pole_na_planszy(pole) and pole_w_granicach(pole) and not (pole in holes):
			_apply_tile(pole)
			if NetworkManager.is_online:
				NetworkManager.submit_action({"type": "tile", "x": pole.x, "y": pole.y})
			$dzwiek/ruch.play()
		else:
			$dzwiek/zakaz.play()
		stan = Stany.IDLE

func stan_hole_placement(pole: Vector2i, pressed: bool) -> void:
	if Input.is_action_just_pressed("hole"):
		stan = Stany.IDLE
		return
	if pressed and not _prev_mouse_pressed:
		if pole_na_planszy(pole) and stoi_figura(pole) == null and pole != duck_position:
			_apply_hole(pole)
			if NetworkManager.is_online:
				NetworkManager.submit_action({"type": "hole", "x": pole.x, "y": pole.y})
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
	# Castling and knight_swap (both clients compute these identically and
	# deterministically from the synced board state, so neither needs its
	# own network message): detect them before figura actually moves.
	var pieces_before := _rules_pieces()
	var mover_index := GameRules.piece_index_at(pieces_before, pozycja(figura))
	var mover_piece: Dictionary = pieces_before[mover_index] if mover_index != -1 else {}
	var castle := GameRules.find_castle_move(active_cards, pieces_before, dostepne_pola, mover_index, cel, duck_position)
	var occupant = stoi_figura(cel)
	var is_swap := occupant != null and CardHooks.piece_swaps_on_contact(active_cards, mover_piece)
	if is_swap:
		# knight_swap: the occupant (friend or foe, even a color's last
		# king) trades places instead of being captured.
		occupant.position = _piece_position(pozycja(figura))
	elif occupant:
		zbicie(occupant)
	figura.position = _piece_position(cel)
	if not castle.is_empty():
		var rook_figure = stoi_figura(castle["rook_from"])
		if rook_figure:
			rook_figure.position = _piece_position(castle["rook_to"])
	var mover := kolor_posuniecia
	if moze_promowac(figura):
		_begin_promotion(figura, mover)
		return
	_continue_after_move(mover)

func _begin_promotion(figura, mover: String) -> void:
	promotion_pending = true
	promotion_figure = figura
	if NetworkManager.is_online and figura.kolor != my_color:
		# The other client is choosing; wait for their "promote" action.
		# Their own turn hasn't ended yet, so our existing turn-based input
		# checks already keep us from touching the board meanwhile.
		return
	stan = Stany.PROMOTION
	promotion_picker.visible = true

func _on_promotion_chosen(piece_type: String) -> void:
	if not promotion_pending:
		return
	var figura = promotion_figure
	figura.promocja(piece_type)
	promotion_pending = false
	promotion_figure = null
	promotion_picker.visible = false
	if NetworkManager.is_online:
		NetworkManager.submit_action({"type": "promote", "piece": piece_type})
	stan = Stany.IDLE
	_continue_after_move(kolor_posuniecia)

func _continue_after_move(mover: String) -> void:
	_refresh_background_tint()
	$dzwiek/ruch.play()
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
	if GameRules.is_dead_position(_rules_pieces()):
		koniec_gry("")
		return
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

# board_hole: the opposite of adding a tile - permanently removes a currently
# playable, empty square from the board. Once removed it can never be added
# back via dodaj_pole(), so it stays an indestructible obstacle for the rest
# of the match.
func _apply_hole(pole: Vector2i) -> void:
	dostepne_pola.erase(pole)
	holes.append(pole)
	if tiles.has(pole):
		tiles[pole].queue_free()
		tiles.erase(pole)
	_hint_key = HINT_KEY_STALE
	if kolor_posuniecia == "b":
		bialy_holes -= 1
	else:
		czarny_holes -= 1

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
			if kolor_posuniecia != my_color and not pole_na_planszy(pole) and pole_w_granicach(pole) and not (pole in holes):
				_apply_tile(pole)
		"hole":
			var hole_target := Vector2i(int(action.get("x", -99)), int(action.get("y", -99)))
			if kolor_posuniecia != my_color and pole_na_planszy(hole_target) and stoi_figura(hole_target) == null and hole_target != duck_position:
				_apply_hole(hole_target)
		"duck":
			var duck_target := Vector2i(int(action.get("x", -99)), int(action.get("y", -99)))
			if kolor_posuniecia != my_color and duck_pending and _can_place_duck(duck_target):
				_apply_duck(duck_target)
				_finish_after_move(kolor_posuniecia)
		"promote":
			if promotion_pending and promotion_figure:
				var piece_type := str(action.get("piece", "H"))
				promotion_figure.promocja(piece_type)
				promotion_pending = false
				promotion_figure = null
				_continue_after_move(kolor_posuniecia)
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

func stoi_figura(pole: Vector2i):
	for figura in figury:
		if pozycja(figura) == pole:
			return figura
	return null

func pozycja(figura) -> Vector2i:
	return _world_to_tile(figura.position)

func dodaj(typ: String, kolor: String, pole: Vector2i) -> void:
	if not pole_na_planszy(pole) or stoi_figura(pole):
		return
	var figura = preload("res://scenes/figura.tscn").instantiate()
	figura.typ = typ
	figura.kolor = kolor
	board_root.add_child(figura)
	figury.append(figura)
	figura.position = _piece_position(pole)

func zbicie(figura) -> void:
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zbicie.play()

func generacja_pol(rozmiar: int) -> void:
	for x in range(1, rozmiar + 1):
		for y in range(1, rozmiar + 1):
			var pole := Vector2i(x, y)
			dostepne_pola.append(pole)
			_spawn_tile(pole)

func pole_w_granicach(pole: Vector2i) -> bool:
	return pole.x >= board_min and pole.x <= board_max and pole.y >= board_min and pole.y <= board_max

func pole_na_planszy(pole: Vector2i) -> bool:
	return pole in dostepne_pola

func dodaj_pole(pole: Vector2i) -> void:
	if not pole_w_granicach(pole) or pole_na_planszy(pole) or pole in holes:
		return
	dostepne_pola.append(pole)
	_spawn_tile(pole)

func _spawn_tile(pole: Vector2i) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(TILE_SIZE_3D, TILE_SIZE_3D)
	mesh_instance.mesh = mesh
	var is_cream := (pole.x + pole.y) % 2 == 0
	mesh_instance.material_override = cream_material if is_cream else dark_material
	mesh_instance.position = _tile_to_world(pole)
	board_root.add_child(mesh_instance)
	tiles[pole] = mesh_instance

# Casts a ray from the camera through the mouse position onto the board's
# ground plane (y=0) and returns the world hit point, or null if the ray
# never crosses it (shouldn't happen with a downward-tilted camera).
func _mouse_ground_point():
	# Rebase onto the board's own viewport, which need not start at (0, 0).
	var mouse := get_viewport().get_mouse_position() - board_container.position
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)

func _pole_pod_myszka() -> Vector2i:
	var hit = _mouse_ground_point()
	return _world_to_tile(hit) if hit != null else INVALID_POLE

func _tile_to_world(pole: Vector2i) -> Vector3:
	return Vector3(pole.x, 0.0, pole.y) * TILE_SIZE_3D

func _world_to_tile(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / TILE_SIZE_3D), roundi(point.z / TILE_SIZE_3D))

# Pieces/markers stand on top of the tile plane instead of being centered
# inside it - see PIECE_Y.
func _piece_position(pole: Vector2i) -> Vector3:
	return _tile_to_world(pole) + Vector3(0.0, PIECE_Y, 0.0)

# Legal-move hints (settings -> "Podświetlaj legalne ruchy"). Beyond ordinary
# moves this also covers the card mechanics that are otherwise impossible to
# guess at: where a new tile may be dropped, where a hole may be punched and
# where the duck may stand.
func odswiez_podpowiedzi() -> void:
	_hint_key = HINT_KEY_STALE # force the next _update_hints() to rebuild
	_update_hints()

func _update_hints() -> void:
	var key := _hint_signature()
	if key == _hint_key:
		return
	_hint_key = key
	_clear_hints()
	match stan:
		Stany.GRAB:
			_draw_move_hints(chwycona, poczatkowe_pole)
		Stany.SELECT:
			_draw_move_hints(wybrana, pozycja(wybrana) if wybrana else Vector2i.ZERO)
		Stany.PLACEMENT:
			for pole in _tile_placement_targets():
				_spawn_hint(pole, place_hint_material)
		Stany.HOLE_PLACEMENT:
			for pole in dostepne_pola:
				if stoi_figura(pole) == null and pole != duck_position:
					_spawn_hint(pole, capture_hint_material)
		Stany.DUCK:
			for pole in dostepne_pola:
				if _can_place_duck(pole):
					_spawn_hint(pole, place_hint_material)

# Cheap stand-in for "would the hints look any different now?" - the board
# can't change while any of these states is active, so the state plus the
# square being asked about is enough to tell.
func _hint_signature() -> String:
	if not PozycjaOsobista.show_legal_moves or game_finished or not input_enabled:
		return ""
	match stan:
		Stany.GRAB:
			return "grab:%s" % poczatkowe_pole
		Stany.SELECT:
			if not wybrana:
				return ""
			return "select:%s" % pozycja(wybrana)
		Stany.PLACEMENT:
			return "tile:%d" % dostepne_pola.size()
		Stany.HOLE_PLACEMENT:
			return "hole:%d" % dostepne_pola.size()
		Stany.DUCK:
			return "duck:%s" % duck_position
	return ""

func _draw_move_hints(figura, from: Vector2i) -> void:
	if not figura:
		return
	# The rules snapshot is built with the moved piece pinned to `from`, not
	# to wherever it currently sits: while it's being dragged its node is
	# under the cursor, which would otherwise poison every legality check.
	var pieces: Array = []
	var index := -1
	for other in figury:
		if other == figura:
			index = pieces.size()
			pieces.append({"type": str(other.typ), "color": str(other.kolor), "x": from.x, "y": from.y})
		else:
			var pole := pozycja(other)
			pieces.append({"type": str(other.typ), "color": str(other.kolor), "x": pole.x, "y": pole.y})
	if index == -1:
		return
	for cel in dostepne_pola:
		if cel == from:
			continue
		if not GameRules.is_legal_move(pieces, dostepne_pola, index, cel, active_cards, duck_position):
			continue
		_spawn_hint(cel, capture_hint_material if _zajete_poza(cel, figura) else move_hint_material)

func _zajete_poza(pole: Vector2i, ignorowana) -> bool:
	for figura in figury:
		if figura != ignorowana and pozycja(figura) == pole:
			return true
	return false

func _tile_placement_targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(board_min, board_max + 1):
		for y in range(board_min, board_max + 1):
			var pole := Vector2i(x, y)
			if not pole_na_planszy(pole) and not (pole in holes):
				result.append(pole)
	return result

func _spawn_hint(pole: Vector2i, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(HINT_SIZE, HINT_SIZE) * TILE_SIZE_3D
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = _tile_to_world(pole) + Vector3(0.0, HINT_Y, 0.0)
	board_root.add_child(mesh_instance)
	hints.append(mesh_instance)

func _clear_hints() -> void:
	for hint in hints:
		hint.queue_free()
	hints.clear()

func _create_duck_marker() -> void:
	duck_marker = Sprite3D.new()
	duck_marker.texture = DUCK_TEXTURE
	duck_marker.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	duck_marker.shaded = false
	duck_marker.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# The 3D texture-filter enum is not the CanvasItem one - nearest is 0 here.
	duck_marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	duck_marker.pixel_size = (TILE_SIZE_3D / 64.0) * 0.28
	duck_marker.visible = false
	board_root.add_child(duck_marker)

func _create_promotion_picker() -> void:
	promotion_picker = PanelContainer.new()
	promotion_picker.visible = false
	promotion_picker.z_index = 10
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	promotion_picker.add_child(box)
	for typ in PROMOTION_CHOICES:
		var button := Button.new()
		button.text = str(PROMOTION_LABELS[typ])
		button.custom_minimum_size = Vector2(68, 54)
		button.pressed.connect(_on_promotion_chosen.bind(typ))
		box.add_child(button)
	add_child(promotion_picker)
	_center_screen_control(promotion_picker, Vector2(300, 70))

func _can_place_duck(pole: Vector2i) -> bool:
	return pole_na_planszy(pole) and pole != duck_position and stoi_figura(pole) == null and not GameRules.is_in_check(_rules_pieces(), dostepne_pola, kolor_posuniecia, active_cards, pole)

func _apply_duck(pole: Vector2i) -> void:
	duck_position = pole
	duck_marker.position = _piece_position(pole)
	duck_marker.visible = true
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
	_prepare_result_screen(kolor_wygranej)
	get_tree().change_scene_to_file("res://scenes/wynik.tscn")

# Placeholder result screen: online shows a big "W FAPS"/"L FAPS" from this
# viewer's own perspective (win or lose), local versus just names the
# winner - both players are watching the same screen, so there's no "you"
# to call out.
func _prepare_result_screen(kolor_wygranej: String) -> void:
	if kolor_wygranej.is_empty():
		PozycjaOsobista.last_result_message = "Remis"
		PozycjaOsobista.last_result_big_text = ""
		return
	var winner_nick := str(player_nicknames.get(kolor_wygranej, ""))
	PozycjaOsobista.last_result_message = winner_nick + " wygrywa"
	if NetworkManager.is_online:
		PozycjaOsobista.last_result_big_text = "W FAPS" if kolor_wygranej == my_color else "L FAPS"
	else:
		PozycjaOsobista.last_result_big_text = ""
