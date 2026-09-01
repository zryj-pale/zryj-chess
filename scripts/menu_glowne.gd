extends Control

const TLO_EKRANU_GLOWNEGO = preload("uid://tvwbs626pujp")

@onready var nickname_input: LineEdit = $NicknameInput
@onready var nickname_status: Label = $NicknameStatus
@onready var nickname_label: Label = $NicknameLabel

# The menu entries are extruded 3D words hanging in front of the animated
# background, not Buttons. Same reason the board lives in its own SubViewport:
# a 2D CanvasItem always draws on top of ANY 3D content sharing a viewport, so
# the signs get their own world and are shown through a container that the 2D
# title and nickname field can still layer over.
const SIGNS_DIR := "res://assets/NAPISY 3D/przyciski 3d/"
const SIGN_SPACING := 1.15 # world units between rows
const SIGN_FOV := 45.0
# How much of the viewport height the whole column is allowed to fill. The
# title sits above it and the nickname field top-right, so it does not get the
# entire screen.
const SIGN_VIEW_FRACTION := 0.58
const SIGNS_Z_INDEX := 4 # above the animated background, below the intro video and the nickname field

var tlo = null
var sign_container: SubViewportContainer
var sign_viewport: SubViewport
var sign_camera: Camera3D
var signs: Array[MenuSign3D] = []

func _ready() -> void:
	tlo = TLO_EKRANU_GLOWNEGO.instantiate()
	add_child(tlo)
	_build_signs()
	nickname_input.text = PozycjaOsobista.nickname
	nickname_input.text_changed.connect(_on_nickname_changed)
	nickname_input.text_submitted.connect(func(_text: String): _save_nickname())
	nickname_label.mouse_filter = Control.MOUSE_FILTER_STOP
	nickname_label.gui_input.connect(_on_nickname_label_input)
	get_viewport().size_changed.connect(_on_window_resized)
	_on_window_resized()
	_refresh_nickname_visibility()
	_refresh_background_tint()
	$muzyka.play()

func _build_signs() -> void:
	sign_container = SubViewportContainer.new()
	sign_container.name = "SignViewportContainer"
	sign_container.stretch = true
	# The signs are hit-tested by hand against their own projected rectangles
	# (see _sign_at), so the container must not swallow clicks meant for the
	# nickname field sitting under it.
	sign_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_container.z_index = SIGNS_Z_INDEX
	add_child(sign_container)

	sign_viewport = SubViewport.new()
	sign_viewport.own_world_3d = true
	sign_viewport.transparent_bg = true
	sign_viewport.handle_input_locally = false
	sign_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sign_container.add_child(sign_viewport)
	Viewport3D.setup(sign_viewport)

	var world := Node3D.new()
	world.name = "Signs"
	sign_viewport.add_child(world)
	MenuSign3D.add_lighting(world)

	sign_camera = Camera3D.new()
	sign_camera.fov = SIGN_FOV
	sign_camera.current = true
	sign_viewport.add_child(sign_camera)

	# File, the word to pull out of it, the label to fall back to, the action.
	# The node name matters because settings.glb is a whole Blender scene with
	# every word in it, not just its own - see MenuSign3D.create().
	var entries := [
		["local.glb", "local", "Lokalna gra", _on_lokalna_pressed],
		["online.glb", "online", "Gra online", _on_online_pressed],
		["postion.glb", "position", "Ustawianie pozycji", _on_ustawianie_pressed],
		["settings.glb", "settings", "Ustawienia", _on_ustawienia_pressed],
		["exit.glb", "exit", "Wyjdź z gry", _on_wyjdz_pressed],
	]
	for i in range(entries.size()):
		var entry: Array = entries[i]
		# The phase offset is what stops the whole column drifting in unison
		# and reading as one rigid slab.
		var item := MenuSign3D.create(SIGNS_DIR + str(entry[0]), str(entry[1]), str(entry[2]), i * 1.37)
		item.on_pressed = entry[3]
		item.base_position = Vector3(0.0, (float(entries.size() - 1) * 0.5 - i) * SIGN_SPACING, 0.0)
		item.position = item.base_position
		world.add_child(item)
		signs.append(item)

func _on_window_resized() -> void:
	Viewport3D.fit_to_pixels(sign_container, Rect2(Vector2.ZERO, get_viewport_rect().size))
	_frame_signs()

# Pulls the camera back until the whole column fits inside SIGN_VIEW_FRACTION
# of the frame, measured from the signs' real extents rather than a guess, so
# a re-exported (longer or taller) word cannot silently run off the edge.
func _frame_signs() -> void:
	if signs.is_empty() or sign_camera == null:
		return
	var widest := 0.0
	var tallest := 0.0
	for item in signs:
		widest = maxf(widest, item.word_size().x)
		tallest = maxf(tallest, item.word_size().y)
	var half_height := ((signs.size() - 1) * SIGN_SPACING + tallest) * 0.5
	var half_width := widest * 0.5
	var viewport_size := Vector2(sign_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	# Camera3D keeps the vertical FOV, so the horizontal half-angle is the one
	# that has to be derived from the aspect ratio.
	var tan_v := tan(deg_to_rad(SIGN_FOV) * 0.5) * SIGN_VIEW_FRACTION
	var tan_h := tan_v * (viewport_size.x / viewport_size.y)
	sign_camera.position = Vector3(0.0, 0.0, maxf(half_height / tan_v, half_width / tan_h))
	sign_camera.rotation = Vector3.ZERO

func _process(_delta: float) -> void:
	var hovered = _sign_at(get_global_mouse_position()) if _signs_active() else null
	for item in signs:
		item.hovered = item == hovered

func _unhandled_input(event: InputEvent) -> void:
	if not _signs_active():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var item := _sign_at(get_global_mouse_position())
	if item != null and item.on_pressed.is_valid():
		get_viewport().set_input_as_handled()
		item.on_pressed.call()

# The intro video covers the whole screen on launch, and the settings overlay
# covers it later; in both cases the signs are not what the player is looking
# at, so they neither light up nor answer clicks.
func _signs_active() -> bool:
	return not $VideoStreamPlayer.visible and not Ustawienia.is_open()

func _sign_at(canvas_point: Vector2) -> MenuSign3D:
	for item in signs:
		var rect := item.hit_rect(sign_camera)
		if rect.size == Vector2.ZERO:
			continue
		var on_canvas := Rect2(Viewport3D.to_canvas(sign_container, rect.position), rect.size * sign_container.scale)
		if on_canvas.has_point(canvas_point):
			return item
	return null

func _refresh_background_tint() -> void:
	# Uses the live input text (not just the saved nickname) so the tint
	# updates as the player types, before they even confirm the nickname.
	var tint := PozycjaOsobista.nickname_color(nickname_input.text)
	tlo.set_match_tint(tint)
	# The signs take the same colour, so they read as part of the scene rather
	# than white words parked in front of it.
	for item in signs:
		item.set_tint(tint)

# Pole nicku ma być widoczne tylko dopóki nick nie jest ustawiony; potem
# chowa się, żeby nie zasłaniać reszty menu. Kliknięcie etykiety pozwala
# wrócić do edycji.
func _refresh_nickname_visibility() -> void:
	var has_nick := PozycjaOsobista.has_nickname()
	nickname_input.visible = not has_nick
	nickname_status.visible = not has_nick
	nickname_label.text = PozycjaOsobista.nickname if has_nick else "Twój nick"

func _on_nickname_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		nickname_input.visible = true
		nickname_status.visible = true
		nickname_input.grab_focus()

func _on_lokalna_pressed() -> void:
	if not _save_nickname():
		return
	if not PozycjaOsobista.any_loadout_has_king():
		# No playable army yet in either slot - send them to set one up
		# instead of starting a match that can't work.
		get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_video_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	$VideoStreamPlayer.visible = false
	$IntroBackdrop.visible = false


func _on_ustawianie_pressed() -> void:
	if not _save_nickname():
		return
	get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")


# Music muting and the key map moved into the shared settings overlay, so
# there is one place to change them from the menu, the army creator and
# mid-match alike.
func _on_ustawienia_pressed() -> void:
	Ustawienia.open()

func _on_wyjdz_pressed() -> void:
	get_tree().quit()

func _on_online_pressed() -> void:
	if not _save_nickname():
		return
	if not PozycjaOsobista.loadout_has_king(0):
		# Online always plays with loadout 1 specifically (see lobby.gd).
		get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_nickname_changed(_value: String) -> void:
	nickname_status.text = ""
	_refresh_background_tint()

func _save_nickname() -> bool:
	if PozycjaOsobista.set_nickname(nickname_input.text):
		nickname_input.text = PozycjaOsobista.nickname
		_refresh_nickname_visibility()
		_refresh_background_tint()
		return true
	nickname_status.text = "Wpisz nick, aby rozpocząć grę."
	nickname_status.visible = true
	nickname_input.grab_focus()
	return false
