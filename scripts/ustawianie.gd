extends Node2D

# See main.gd for why the board lives inside its own SubViewport: 2D
# CanvasItems (all the UI here) always draw on top of 3D World content in a
# shared viewport, with no way to sort one behind the other, so the 3D board
# is rendered separately and displayed through a fullscreen container that
# behaves like any other 2D drawable.
@onready var board_container: SubViewportContainer = $BoardViewportContainer
@onready var board_viewport: SubViewport = $BoardViewportContainer/BoardViewport
@onready var board_root: Node3D = $BoardViewportContainer/BoardViewport/BoardRoot
@onready var camera_rig: Node3D = $BoardViewportContainer/BoardViewport/CameraRig
@onready var camera: Camera3D = $BoardViewportContainer/BoardViewport/CameraRig/Camera3D
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var punkty_label: Label = $PunktyLabel
@onready var cards_toggle: Button = $CardsToggle
@onready var loadout_buttons: Array[Button] = [$Loadout1Button, $Loadout2Button]

const MAX_PUNKTY := 16
const SZARY_KOLOR := Color(0.55, 0.55, 0.55, 1.0)
const WARTOSCI_FIGUR := {"P": 1, "S": 2, "G": 2, "W": 4, "H": 6, "K": 6}

const TILE_SIZE_3D := 1.0
const PIECE_Y := TILE_SIZE_3D * 0.5 # lifts pieces so they stand on the tile plane instead of poking through it
const PIECE_HEIGHT := TILE_SIZE_3D # a billboard piece is one tile tall; the camera has to keep its top in frame too
const CAMERA_TILT_DEG := 55.0 # degrees down from horizontal - the "old 3D game" angled look
const CAMERA_MIN_DISTANCE := 1.0
const CAMERA_FRAMING_MARGIN := 1.05 # extra breathing room so the board doesn't touch the viewport edges
const INVALID_POLE := Vector2i(-9999, -9999)
const DRAG_MOVE_THRESHOLD := 4.0 / 64.0 # was "4px" back when a tile was 64px; scaled to the new 1.0-unit tile
# The creator's 2D UI brackets the board: buttons above, the point bar below.
# Back in 2D the board was simply parked in that gap and never reached them;
# a centered 3D camera would, because a piece billboard standing on the far
# row rises well above the board's own top edge. So the board's viewport is
# inset into the same gap instead of filling the window.
const BOARD_AREA_TOP := 152.0
const BOARD_AREA_BOTTOM := 428.0

var figury: Array = []
var dostepne_pola: Array[Vector2i] = []
var tiles: Dictionary = {} # Vector2i -> BoardTile, mirrors dostepne_pola visually
var board_min_v := Vector2i.ZERO
var board_max_v := Vector2i.ZERO
var dragging := false
var drag_piece_type := ""
var drag_preview = null
var dragged_figure = null
var drag_origin := Vector2i.ZERO
var drag_moved := false

func _ready() -> void:
	BoardTile.setup_board(board_viewport, board_root)
	generacja_pol(1, 4, 6, 6)
	_compute_board_bounds()
	for pole in dostepne_pola:
		_spawn_tile(pole)
	_on_window_resized()
	get_viewport().size_changed.connect(_on_window_resized)
	synchronizacja()
	cards_toggle.pressed.connect(_on_cards_toggle_pressed)
	for i in range(loadout_buttons.size()):
		loadout_buttons[i].pressed.connect(_on_loadout_slot_pressed.bind(i))
	_refresh_loadout_buttons()

# A Control parented to a Node2D anchors against an EMPTY rect, so "full
# rect" anchors silently collapse the container to 0x0 and none of the board
# is ever drawn. Size and place the container by hand instead (see
# BOARD_AREA_TOP for why it is inset rather than fullscreen); its `stretch`
# then keeps the SubViewport - and with it the Camera3D's aspect ratio -
# matched to the container. BoardTile.fit_to_pixels() is what decides how big
# that actually is in pixels, and why it is not simply the 2D size.
func _on_window_resized() -> void:
	var viewport_size := get_viewport_rect().size
	var height := maxf(1.0, minf(viewport_size.y, BOARD_AREA_BOTTOM) - BOARD_AREA_TOP)
	BoardTile.fit_to_pixels(board_container, Rect2(0.0, BOARD_AREA_TOP, viewport_size.x, height))
	_center_camera()

func _compute_board_bounds() -> void:
	var min_pole := dostepne_pola[0]
	var max_pole := dostepne_pola[0]
	for pole in dostepne_pola:
		min_pole = Vector2i(mini(min_pole.x, pole.x), mini(min_pole.y, pole.y))
		max_pole = Vector2i(maxi(max_pole.x, pole.x), maxi(max_pole.y, pole.y))
	board_min_v = min_pole
	board_max_v = max_pole

# Frames the camera so the whole (fixed-size) creator board fits inside the
# viewport, at a fixed angled tilt - no flipping needed here, unlike the
# match scene, since there's only ever one local player looking at this
# screen.
func _center_camera() -> void:
	var center := Vector2((board_min_v.x + board_max_v.x) / 2.0, (board_min_v.y + board_max_v.y) / 2.0)
	camera_rig.position = Vector3(center.x, 0.0, center.y) * TILE_SIZE_3D
	var half_x := (board_max_v.x - board_min_v.x + 1) * TILE_SIZE_3D * 0.5
	var half_z := (board_max_v.y - board_min_v.y + 1) * TILE_SIZE_3D * 0.5
	# No player colours to mix on this screen - the army creator is neutral -
	# so the lamp keeps its default white.
	BoardTile.focus_lighting(board_root, Vector3(center.x, 0.0, center.y) * TILE_SIZE_3D, maxf(half_x, half_z))
	_place_camera(half_x, half_z)

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

func _on_loadout_slot_pressed(index: int) -> void:
	if index == PozycjaOsobista.editing_loadout_index:
		_refresh_loadout_buttons()
		return
	PozycjaOsobista.save_loadouts()
	PozycjaOsobista.editing_loadout_index = index
	_cancel_drag()
	synchronizacja()
	_refresh_loadout_buttons()

func _refresh_loadout_buttons() -> void:
	for i in range(loadout_buttons.size()):
		loadout_buttons[i].button_pressed = i == PozycjaOsobista.editing_loadout_index

func _process(_delta: float) -> void:
	_sync_levitation()
	# The settings overlay sits above every scene and eats GUI clicks, but
	# the drag itself follows the mouse from here, so it has to be dropped
	# explicitly - otherwise a piece stays glued to the cursor behind the panel.
	if Ustawienia.is_open():
		if dragging:
			_cancel_drag()
	elif dragging:
		var hit = _mouse_ground_point()
		if hit != null:
			var lifted: Vector3 = hit + Vector3(0.0, PIECE_Y, 0.0)
			if dragged_figure:
				dragged_figure.position = lifted
				if lifted.distance_to(_piece_position(drag_origin)) > DRAG_MOVE_THRESHOLD:
					drag_moved = true
			elif drag_preview:
				drag_preview.position = lifted
	var punkty := oblicz_punkty()
	progress_bar.value = punkty
	punkty_label.text = str(punkty) + "/" + str(MAX_PUNKTY)
	progress_bar.modulate = SZARY_KOLOR
	punkty_label.modulate = SZARY_KOLOR

func _on_piece_selected(typ: String) -> void:
	drag_piece_type = typ
	dragging = true
	if drag_preview:
		drag_preview.queue_free()
	drag_preview = preload("res://scenes/figura.tscn").instantiate()
	drag_preview.typ = typ
	drag_preview.kolor = "b"
	drag_preview.modulate = Color(0.55, 0.55, 0.55, 0.7)
	board_root.add_child(drag_preview)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if dragging:
		if dragged_figure:
			if not event.pressed:
				_finish_figure_drag()
			return
		if not event.pressed:
			return
		var pole := _pole_pod_myszka()
		if pole_na_planszy(pole) and not stoi_figura(pole) and can_place(drag_piece_type):
			dodaj(drag_piece_type, pole)
			PozycjaOsobista.ustawienie.append([drag_piece_type, pole])
		_cancel_drag()
		return
	if not event.pressed:
		return
	var pole := _pole_pod_myszka()
	var figura = stoi_figura(pole)
	if figura:
		_begin_figure_drag(figura)

func _begin_figure_drag(figura) -> void:
	dragging = true
	dragged_figure = figura
	drag_origin = pozycja(figura)
	drag_moved = false

func _finish_figure_drag() -> void:
	var figura = dragged_figure
	var destination := _pole_pod_myszka()
	figura.position = _piece_position(drag_origin)
	var target = stoi_figura(destination)
	if pole_na_planszy(destination) and (not target or target == figura):
		if destination != drag_origin:
			figura.position = _piece_position(destination)
			_zapisz_przesuniecie(figura, drag_origin, destination)
		elif not drag_moved:
			usun_figure(figura)
	elif destination != drag_origin:
		$dzwiek/zakaz.play()
	dragged_figure = null
	dragging = false
	drag_moved = false

func _zapisz_przesuniecie(figura, from: Vector2i, to: Vector2i) -> void:
	for index in range(PozycjaOsobista.ustawienie.size()):
		var saved = PozycjaOsobista.ustawienie[index]
		if saved[0] == figura.typ and saved[1] == from:
			saved[1] = to
			PozycjaOsobista.ustawienie[index] = saved
			return

func _cancel_drag() -> void:
	if dragged_figure:
		dragged_figure.position = _piece_position(drag_origin)
		dragged_figure = null
	dragging = false
	drag_piece_type = ""
	drag_moved = false
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func dodaj(typ: String, pole: Vector2i) -> void:
	var figura = preload("res://scenes/figura.tscn").instantiate()
	figura.typ = typ
	figura.kolor = "b"
	figura.modulate = SZARY_KOLOR
	board_root.add_child(figura)
	figury.append(figura)
	figura.position = _piece_position(pole)

func usun_figure(figura) -> void:
	var pole: Vector2i = pozycja(figura)
	for i in range(PozycjaOsobista.ustawienie.size() - 1, -1, -1):
		var ustawienie = PozycjaOsobista.ustawienie[i]
		if ustawienie[0] == figura.typ and ustawienie[1] == pole:
			PozycjaOsobista.ustawienie.remove_at(i)
			break
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zakaz.play()

func oblicz_punkty() -> int:
	var wynik := 0
	for ustawienie in PozycjaOsobista.ustawienie:
		wynik += WARTOSCI_FIGUR.get(ustawienie[0], 0)
	return wynik

func can_place(typ: String) -> bool:
	if oblicz_punkty() + WARTOSCI_FIGUR.get(typ, 0) <= MAX_PUNKTY:
		return true
	$dzwiek/zakaz.play()
	return false

func pozycja(figura) -> Vector2i:
	return _world_to_tile(figura.position)

func stoi_figura(pole: Vector2i):
	for figura in figury:
		if pozycja(figura) == pole:
			return figura
	return null

func pole_na_planszy(pole: Vector2i) -> bool:
	return pole in dostepne_pola

func generacja_pol(x: int, y: int, width: int, height: int) -> void:
	for w in range(x, width + 1):
		for h in range(y, height + 1):
			dostepne_pola.append(Vector2i(w, h))

func _spawn_tile(pole: Vector2i) -> void:
	var is_light := (pole.x + pole.y) % 2 == 0
	var tile := BoardTile.create(pole, _tile_to_world(pole), TILE_SIZE_3D, is_light)
	board_root.add_child(tile)
	tiles[pole] = tile

# Casts a ray from the camera through the mouse position onto the board's
# ground plane (y=0) and returns the world hit point, or null if the ray
# never crosses it (shouldn't happen with a downward-tilted camera).
# Pieces are placed on the fixed grid, not on the plates, so without this
# they would stand still while the plate under them floats out from under
# their feet. A piece's own node position is what pozycja() reads back to tell
# which square it is on, so that must not be nudged - the drift goes on the
# sprite child instead, where it is purely visual.
func _sync_levitation() -> void:
	for figura in figury:
		var sprite: Node3D = figura.get_node_or_null("tekstura")
		if sprite == null:
			continue
		# A dragged piece hangs off the cursor rather than off any one square.
		sprite.position = Vector3.ZERO if figura == dragged_figure else _levitation_at(pozycja(figura))

func _levitation_at(pole: Vector2i) -> Vector3:
	var tile = tiles.get(pole)
	return tile.levitation_offset() if tile != null else Vector3.ZERO

func _mouse_ground_point():
	# The board's viewport is inset inside the window, so a mouse position read
	# from the outer 2D viewport has to be rebased onto it first - and it is
	# not drawn at 1:1 either: it renders at real screen pixels and is scaled
	# back down to fit the 2D layout, so undo that scale too
	# (BoardTile.fit_to_pixels).
	var mouse := (get_viewport().get_mouse_position() - board_container.position) / board_container.scale
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

# Pieces stand on top of the tile plane instead of being centered inside it -
# see PIECE_Y.
func _piece_position(pole: Vector2i) -> Vector3:
	return _tile_to_world(pole) + Vector3(0.0, PIECE_Y, 0.0)

func reset() -> void:
	for figura in figury:
		figura.queue_free()
	figury.clear()

func synchronizacja() -> void:
	reset()
	# Defensively re-validate on every load/slot-switch: a piece outside
	# dostepne_pola (or stacked on another piece) would otherwise render
	# with no board tile under it - "floating" - and still count toward the
	# point budget. Drop those and persist the cleanup so it sticks.
	var valid: Array = []
	for ustawienie in PozycjaOsobista.ustawienie:
		if ustawienie is Array and ustawienie.size() == 2 and typeof(ustawienie[1]) == TYPE_VECTOR2I \
				and pole_na_planszy(ustawienie[1]) and stoi_figura(ustawienie[1]) == null:
			dodaj(ustawienie[0], ustawienie[1])
			valid.append(ustawienie)
	if valid.size() != PozycjaOsobista.ustawienie.size():
		PozycjaOsobista.ustawienie = valid
		PozycjaOsobista.save_loadouts()

func _on_reset_pressed() -> void:
	_cancel_drag()
	reset()
	PozycjaOsobista.ustawienie.clear()
	PozycjaOsobista.save_loadouts()

func _on_menu_pressed() -> void:
	PozycjaOsobista.save_loadouts()
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

func _on_cards_toggle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/karty.tscn")
