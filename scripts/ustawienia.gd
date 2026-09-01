extends CanvasLayer

# Autoloaded settings/pause overlay. It lives above every scene rather than
# being instanced per screen, so `pause` (Esc by default) opens the same
# panel in the menu, the army creator, the card collection and mid-match -
# and the match-only "leave match" button simply appears when a match is
# actually running, found the same way hud.gd finds it.
#
# The tree is deliberately NOT paused while this is open: NetworkManager is
# an autoload that keeps an online match alive from _process, and the coin
# toss temporarily rewrites Engine.time_scale. Instead the two screens that
# poll the mouse directly (main.gd, ustawianie.gd) ask is_open() and skip
# their own input handling.

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const PANEL_WIDTH := 420.0

var _root: Control
var _panel: PanelContainer
var _mute_check: CheckButton
var _legal_moves_check: CheckButton
var _keybind_buttons := {} # action -> Button
var _exit_button: Button
var _capturing_action := ""

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false

func is_open() -> bool:
	return visible

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	# The default theme's panel is translucent, which lets the screen behind
	# show through the settings and makes both unreadable.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.12)
	style.border_color = Color(0.38, 0.38, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Ustawienia"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HSeparator.new())

	_mute_check = CheckButton.new()
	_mute_check.text = "Wycisz muzykę"
	_mute_check.toggled.connect(func(value: bool): PozycjaOsobista.set_music_muted(value))
	box.add_child(_mute_check)

	_legal_moves_check = CheckButton.new()
	_legal_moves_check.text = "Podświetlaj legalne ruchy"
	_legal_moves_check.tooltip_text = "Pokazuje pola, na które może wejść trzymana figura, oraz gdzie wolno dołożyć pole, wybić dziurę i postawić kaczkę."
	_legal_moves_check.toggled.connect(_on_legal_moves_toggled)
	box.add_child(_legal_moves_check)

	box.add_child(HSeparator.new())
	var controls_title := Label.new()
	controls_title.text = "Sterowanie"
	box.add_child(controls_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for action in PozycjaOsobista.REMAPPABLE_ACTIONS:
		var label := Label.new()
		label.text = str(PozycjaOsobista.REMAPPABLE_ACTIONS[action])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 0)
		button.pressed.connect(_on_keybind_pressed.bind(action))
		grid.add_child(button)
		_keybind_buttons[action] = button

	var reset_button := Button.new()
	reset_button.text = "Przywróć domyślne klawisze"
	reset_button.pressed.connect(_on_reset_keybinds)
	box.add_child(reset_button)

	box.add_child(HSeparator.new())

	_exit_button = Button.new()
	_exit_button.text = "Wyjdź z meczu"
	_exit_button.pressed.connect(_on_exit_match)
	box.add_child(_exit_button)

	var close_button := Button.new()
	close_button.text = "Wróć"
	close_button.pressed.connect(close)
	box.add_child(close_button)

func open() -> void:
	_capturing_action = ""
	_mute_check.set_pressed_no_signal(PozycjaOsobista.music_muted)
	_legal_moves_check.set_pressed_no_signal(PozycjaOsobista.show_legal_moves)
	_exit_button.visible = _current_match() != null
	_refresh_keybind_labels()
	visible = true

func close() -> void:
	_capturing_action = ""
	_refresh_keybind_labels()
	visible = false

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func _current_match():
	return get_tree().get_first_node_in_group("game_main")

func _refresh_keybind_labels() -> void:
	for action in _keybind_buttons:
		var button: Button = _keybind_buttons[action]
		if action == _capturing_action:
			button.text = "Naciśnij klawisz…"
		else:
			button.text = PozycjaOsobista.keybind_label(action)

func _on_keybind_pressed(action: String) -> void:
	_capturing_action = action
	_refresh_keybind_labels()

func _on_reset_keybinds() -> void:
	_capturing_action = ""
	PozycjaOsobista.reset_keybinds()
	_refresh_keybind_labels()

func _on_legal_moves_toggled(value: bool) -> void:
	PozycjaOsobista.set_show_legal_moves(value)
	var match_scene = _current_match()
	if match_scene and match_scene.has_method("odswiez_podpowiedzi"):
		match_scene.odswiez_podpowiedzi()

func _on_exit_match() -> void:
	var match_scene = _current_match()
	close()
	if match_scene and match_scene.has_method("opusc_mecz"):
		match_scene.opusc_mecz()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _capturing_action != "":
		# Escape backs out of rebinding instead of being bound, so `pause`
		# can never be reassigned to a key by accident while capturing.
		if event.keycode != KEY_ESCAPE:
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			PozycjaOsobista.set_keybind(_capturing_action, keycode)
		_capturing_action = ""
		_refresh_keybind_labels()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
