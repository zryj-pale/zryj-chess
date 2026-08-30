extends CanvasLayer

@onready var bialy_label = $BialyLabel
@onready var czarny_label = $CzarnyLabel
@onready var cards_label = $CardsLabel

func _process(_delta):
	var main = get_tree().get_first_node_in_group("game_main")
	if main:
		bialy_label.text = str(main.player_nicknames.get("b", "Białe")) + " (białe): " + str(main.bialy_tiles)
		czarny_label.text = str(main.player_nicknames.get("c", "Czarne")) + " (czarne): " + str(main.czarny_tiles)
		if main.kolor_posuniecia == "b":
			bialy_label.modulate = Color.WHITE
			czarny_label.modulate = Color.GRAY
		else:
			bialy_label.modulate = Color.GRAY
			czarny_label.modulate = Color.WHITE
		cards_label.text = "Białe: " + CardRegistry.display_name(str(main.active_cards.get("b", ""))) + "\nCzarne: " + CardRegistry.display_name(str(main.active_cards.get("c", "")))
		if main.duck_pending:
			cards_label.text += "\nUstaw kaczkę, aby zakończyć turę."
