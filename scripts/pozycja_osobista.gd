extends Node

const PROFILE_PATH := "user://profile.cfg"
const PROFILE_SECTION := "player"
const PROFILE_NICKNAME_KEY := "nickname"
const PROFILE_MUSIC_MUTED_KEY := "music_muted"
const PROFILE_LOADOUTS_KEY := "loadouts"
const LOADOUT_COUNT := 2

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
	_load_profile()
	_apply_music_mute()

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
	profile.set_value(PROFILE_SECTION, PROFILE_LOADOUTS_KEY, loadouts)
	profile.save(PROFILE_PATH)
