extends Node

const PROFILE_PATH := "user://profile.cfg"
const PROFILE_SECTION := "player"
const PROFILE_NICKNAME_KEY := "nickname"
const PROFILE_MUSIC_MUTED_KEY := "music_muted"
const PROFILE_LOADOUTS_KEY := "loadouts"
const PROFILE_LEGAL_MOVES_KEY := "show_legal_moves"
const PROFILE_KEYBINDS_KEY := "keybinds"
const LOADOUT_COUNT := 2

# Every action the player is allowed to rebind, in the order the settings
# screen lists them. Anything not in here (the built-in ui_* actions) stays
# fixed, so the player can never lock themselves out of the UI.
const REMAPPABLE_ACTIONS := {
	"space": "Dołóż pole",
	"hole": "Wybij dziurę",
	"pause": "Ustawienia / pauza",
}

# Two saved army+card loadouts. In local versus, white and black each pick
# one before the coin toss (main.gd's loadout picker); online always uses
# loadouts[0]. The setup and card-collection screens only ever edit
# whichever slot `editing_loadout_index` points at, through `ustawienie`/
# `wybrana_karta` below - a live view onto that slot, so those screens don't
# need to know slots exist at all.
var loadouts: Array = []
var editing_loadout_index := 0
var nickname := ""
var music_muted := false
var show_legal_moves := true

# action -> physical keycode. `defaults` is whatever project.godot shipped
# with, captured before any saved override is applied, so "przywróć
# domyślne" has something to go back to.
var keybinds := {}
var default_keybinds := {}

# Transient hand-off to scenes/wynik.tscn - never persisted. main.gd fills
# these in right before changing to that scene.
var last_result_message := ""
var last_result_big_text := ""

var ustawienie: Array:
	get:
		return loadouts[editing_loadout_index]["ustawienie"]
	set(value):
		loadouts[editing_loadout_index]["ustawienie"] = value

var wybrana_karta: String:
	get:
		return loadouts[editing_loadout_index]["karta"]
	set(value):
		loadouts[editing_loadout_index]["karta"] = value
		_save_profile()

func _ready() -> void:
	_ensure_loadouts()
	_capture_default_keybinds()
	_load_profile()
	_apply_music_mute()
	_apply_keybinds()

func _ensure_loadouts() -> void:
	while loadouts.size() < LOADOUT_COUNT:
		loadouts.append({"ustawienie": [], "karta": ""})

# A match needs a king to be playable at all. Checked at the point a match
# actually starts (menu_glowne.gd for local, lobby.gd for online), not when
# just leaving the setup screen - you can always go back to the main menu
# with an incomplete or empty army.
func loadout_has_king(index: int) -> bool:
	if index < 0 or index >= loadouts.size():
		return false
	for piece in loadouts[index]["ustawienie"]:
		if piece is Array and piece.size() >= 1 and str(piece[0]) == "K":
			return true
	return false

func any_loadout_has_king() -> bool:
	for i in range(loadouts.size()):
		if loadout_has_king(i):
			return true
	return false

# Piece placement mutates the ustawienie array returned by the getter above
# in place (append/clear/remove_at), which never goes through a property
# setter, so screens that edit a loadout call this explicitly when they're
# done (leaving ustawianie.tscn or karty.tscn, switching slots).
func save_loadouts() -> void:
	_save_profile()

func set_show_legal_moves(value: bool) -> void:
	show_legal_moves = value
	_save_profile()

func _capture_default_keybinds() -> void:
	for action in REMAPPABLE_ACTIONS:
		default_keybinds[action] = _project_keycode(action)
	keybinds = default_keybinds.duplicate()

func _project_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			# Physical keycodes are what the actions ship with, so the binding
			# follows the key's position rather than the keyboard layout.
			return event.physical_keycode if event.physical_keycode != 0 else event.keycode
	return 0

func _apply_keybinds() -> void:
	for action in keybinds:
		if not InputMap.has_action(action):
			continue
		var keycode := int(keybinds[action])
		if keycode == 0:
			continue
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)

# Rebinding onto a key another action already uses SWAPS the two rather than
# stealing it: that way no action is ever left without a key, which for
# `pause` in particular would mean no way back into the settings screen.
func set_keybind(action: String, keycode: int) -> void:
	if keycode == 0 or not keybinds.has(action):
		return
	var previous := int(keybinds[action])
	for other in keybinds.keys():
		if other != action and int(keybinds[other]) == keycode:
			keybinds[other] = previous
	keybinds[action] = keycode
	_apply_keybinds()
	_save_profile()

func reset_keybinds() -> void:
	keybinds = default_keybinds.duplicate()
	_apply_keybinds()
	_save_profile()

func keybind_label(action: String) -> String:
	var keycode := int(keybinds.get(action, 0))
	if keycode == 0:
		return "—"
	return OS.get_keycode_string(keycode)

func set_music_muted(value: bool) -> void:
	music_muted = value
	_apply_music_mute()
	_save_profile()

func _apply_music_mute() -> void:
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index != -1:
		AudioServer.set_bus_mute(bus_index, music_muted)

func set_nickname(value: String) -> bool:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return false
	nickname = cleaned
	_save_profile()
	return true

func has_nickname() -> bool:
	return not nickname.strip_edges().is_empty()

func nickname_color(value := nickname) -> Color:
	var canonical := value.strip_edges().to_lower()
	if canonical.is_empty():
		return Color.WHITE
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(canonical.to_utf8_buffer())
	var digest: PackedByteArray = hasher.finish()
	return Color.from_hsv(
		float(digest[0]) / 255.0,
		0.65 + float(digest[1]) / 255.0 * 0.25,
		0.75 + float(digest[2]) / 255.0 * 0.20
	)

func _load_profile() -> void:
	var profile := ConfigFile.new()
	if profile.load(PROFILE_PATH) == OK:
		nickname = str(profile.get_value(PROFILE_SECTION, PROFILE_NICKNAME_KEY, "")).strip_edges()
		music_muted = bool(profile.get_value(PROFILE_SECTION, PROFILE_MUSIC_MUTED_KEY, false))
		show_legal_moves = bool(profile.get_value(PROFILE_SECTION, PROFILE_LEGAL_MOVES_KEY, true))
		var saved_keybinds = profile.get_value(PROFILE_SECTION, PROFILE_KEYBINDS_KEY, {})
		if saved_keybinds is Dictionary:
			for action in keybinds.keys():
				var keycode := int(saved_keybinds.get(action, 0))
				if keycode != 0:
					keybinds[action] = keycode
		var saved_loadouts = profile.get_value(PROFILE_SECTION, PROFILE_LOADOUTS_KEY, [])
		if saved_loadouts is Array:
			for i in range(mini(saved_loadouts.size(), LOADOUT_COUNT)):
				var entry = saved_loadouts[i]
				if entry is Dictionary:
					loadouts[i] = {
						"ustawienie": entry.get("ustawienie", []),
						"karta": str(entry.get("karta", "")),
					}

func _save_profile() -> void:
	var profile := ConfigFile.new()
	profile.set_value(PROFILE_SECTION, PROFILE_NICKNAME_KEY, nickname)
	profile.set_value(PROFILE_SECTION, PROFILE_MUSIC_MUTED_KEY, music_muted)
	profile.set_value(PROFILE_SECTION, PROFILE_LEGAL_MOVES_KEY, show_legal_moves)
	profile.set_value(PROFILE_SECTION, PROFILE_KEYBINDS_KEY, keybinds)
	profile.set_value(PROFILE_SECTION, PROFILE_LOADOUTS_KEY, loadouts)
	profile.save(PROFILE_PATH)
