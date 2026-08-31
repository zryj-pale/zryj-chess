extends Node

const PROFILE_PATH := "user://profile.cfg"
const PROFILE_SECTION := "player"
const PROFILE_NICKNAME_KEY := "nickname"
const PROFILE_MUSIC_MUTED_KEY := "music_muted"

# Neutralny układ przygotowany przez jednego gracza w ekranie ustawiania.
# W meczu online host otrzymuje z niego białe, a gość czarne figury.
var ustawienie: Array = []
var wybrana_karta := ""
var nickname := ""
var music_muted := false

func _ready() -> void:
	_load_profile()
	_apply_music_mute()

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

func _save_profile() -> void:
	var profile := ConfigFile.new()
	profile.set_value(PROFILE_SECTION, PROFILE_NICKNAME_KEY, nickname)
	profile.set_value(PROFILE_SECTION, PROFILE_MUSIC_MUTED_KEY, music_muted)
	profile.save(PROFILE_PATH)
