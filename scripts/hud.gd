extends CanvasLayer

@onready var bialy_label: Label = $BialyLabel
@onready var czarny_label: Label = $CzarnyLabel
@onready var cards_label: Label = $CardsLabel
@onready var tura_label: Label = $TuraLabel

const AKTYWNY_KOLOR := Color.WHITE
const NIEAKTYWNY_KOLOR := Color(0.55, 0.55, 0.55)
const NAZWY_STRON := {"b": "Białe", "c": "Czarne"}

func _process(_delta: float) -> void:
	var main = get_tree().get_first_node_in_group("game_main")
	if not main:
		return
	var na_ruchu := str(main.kolor_posuniecia)
	bialy_label.text = _wiersz_strony(main, "b")
	czarny_label.text = _wiersz_strony(main, "c")
	bialy_label.modulate = AKTYWNY_KOLOR if na_ruchu == "b" else NIEAKTYWNY_KOLOR
	czarny_label.modulate = AKTYWNY_KOLOR if na_ruchu == "c" else NIEAKTYWNY_KOLOR
	tura_label.text = "Ruch: " + _nazwa_strony(main, na_ruchu)
	# Each player's nickname hashes to their own colour (see
	# PozycjaOsobista.nickname_color), the same one tinting the background -
	# so whose turn it is reads at a glance without parsing any text.
	tura_label.modulate = main.player_colors.get(na_ruchu, Color.WHITE)
	cards_label.text = "Białe: " + CardRegistry.display_name(str(main.active_cards.get("b", ""))) \
		+ "\nCzarne: " + CardRegistry.display_name(str(main.active_cards.get("c", "")))
	if main.duck_pending:
		cards_label.text += "\nUstaw kaczkę, aby zakończyć turę."

func _nazwa_strony(main, kolor: String) -> String:
	var nick := str(main.player_nicknames.get(kolor, ""))
	var nazwa := str(NAZWY_STRON.get(kolor, kolor))
	return nazwa if nick.is_empty() else "%s (%s)" % [nazwa, nick]

# "▶" marks the side to move, on top of the brightness difference - the
# counters themselves stay readable for both sides either way.
func _wiersz_strony(main, kolor: String) -> String:
	var prefiks := "▶ " if str(main.kolor_posuniecia) == kolor else "   "
	var pola: int = main.bialy_tiles if kolor == "b" else main.czarny_tiles
	var wiersz := "%s%s — pola: %d" % [prefiks, _nazwa_strony(main, kolor), pola]
	# The hole counter only makes sense for a side actually holding
	# board_hole; showing "dziury: 0" for them is the point (it says the one
	# hole is already spent), showing it for everyone else is just noise.
	if CardHooks.starting_holes(main.active_cards, kolor) > 0:
		var dziury: int = main.bialy_holes if kolor == "b" else main.czarny_holes
		wiersz += " · dziury: %d" % dziury
	return wiersz
