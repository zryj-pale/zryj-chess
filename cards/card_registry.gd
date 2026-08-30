class_name CardRegistry
extends RefCounted

# One small, data-first registry.  Rules code only asks about card ids/hooks,
# which keeps future cards out of the UI and networking layers.
const NONE := ""
const CARDS := {
	"pat_win": {"name": "Pat to wygrana", "description": "Gdy przeciwnik ma pat, wygrywasz.", "hooks": ["stalemate"]},
	"racing_kings": {"name": "Wyścig królów", "description": "Doprowadź króla do przeciwległej krawędzi planszy.", "hooks": ["win_condition"]},
	"indestructible_pawns": {"name": "Niezniszczalne piony", "description": "Wszystkie piony są nieruchome, nie atakują i nie mogą być bite.", "hooks": ["moves", "capture", "attacks"]},
	"duck_chess": {"name": "Kacze szachy", "description": "Po ruchu figury ustaw kaczkę na wolnym polu.", "hooks": ["blocked_squares", "after_move"]},
	"check_adds_tile": {"name": "Szach daje pole", "description": "Szach ostatniego króla przeciwnika daje dodatkowe pole.", "hooks": ["after_move"]},
}

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in CARDS:
		ids.append(id)
	return ids

static func is_valid(id: String) -> bool:
	return id.is_empty() or CARDS.has(id)

static func display_name(id: String) -> String:
	return str(CARDS.get(id, {}).get("name", "Brak karty"))

static func description(id: String) -> String:
	return str(CARDS.get(id, {}).get("description", "Bez aktywnej karty."))

static func has(cards: Dictionary, color: String, id: String) -> bool:
	return str(cards.get(color, "")) == id

static func any_has(cards: Dictionary, id: String) -> bool:
	return has(cards, "b", id) or has(cards, "c", id)

# Card id pairs that must never both be active in the same match. Each entry
# is a 2-element Array of ids; order does not matter. Empty for now — none of
# the current cards conflict, but a match can be rejected before it starts by
# listing a pair here without touching any rules/UI/network call sites.
const INCOMPATIBLE_PAIRS: Array = []

static func is_compatible(white_id: String, black_id: String) -> bool:
	if white_id.is_empty() or black_id.is_empty() or white_id == black_id:
		return true
	for pair in INCOMPATIBLE_PAIRS:
		if (pair[0] == white_id and pair[1] == black_id) or (pair[0] == black_id and pair[1] == white_id):
			return false
	return true
