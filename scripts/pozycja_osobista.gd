extends Node

const PROFILE_PATH := "user://profile.cfg"
const PROFILE_SECTION := "player"
const PROFILE_NICKNAME_KEY := "nickname"

# Neutralny układ przygotowany przez jednego gracza w ekranie ustawiania.
# W meczu online host otrzymuje z niego białe, a gość czarne figury.
var ustawienie: Array = []
var wybrana_karta := ""
var nickname := ""

func _ready() -> void:
	_load_profile()

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

func _save_profile() -> void:
	var profile := ConfigFile.new()
	profile.set_value(PROFILE_SECTION, PROFILE_NICKNAME_KEY, nickname)
	profile.save(PROFILE_PATH)
