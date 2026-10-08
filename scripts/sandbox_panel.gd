extends CanvasLayer

var game
var toolbar: PanelContainer
var collection: AcceptDialog

func _ready() -> void:
	layer = 3
	toolbar = PanelContainer.new()
	add_child(toolbar)
	var box := VBoxContainer.new()
	toolbar.add_child(box)
	var info := Label.new()
	info.text = "Sandbox · bez tur · pola / dziury: ∞ · PPM: usuń"
	info.add_theme_font_size_override("font_size", 14)
	box.add_child(info)
	var row := HBoxContainer.new()
	box.add_child(row)
	var colors := OptionButton.new()
	colors.add_item("Białe")
	colors.add_item("Czarne")
	colors.item_selected.connect(func(i: int): game.sandbox_color = "b" if i == 0 else "c")
	row.add_child(colors)
	var pieces := OptionButton.new()
	var ids := ["", "P", "S", "G", "W", "H", "K", "duck"]
	for label in ["Przenoś", "Dodaj pion", "Dodaj skoczka", "Dodaj gońca", "Dodaj wieżę", "Dodaj hetmana", "Dodaj króla", "Ustaw kaczkę"]:
		pieces.add_item(label)
	pieces.item_selected.connect(func(i: int):
		game._cancel_grab()
		game.sandbox_piece = ids[i]
	)
	row.add_child(pieces)
	var cards := Button.new()
	cards.text = "Kolekcja kart"
	cards.pressed.connect(func():
		game._cancel_grab()
		collection.popup_centered(Vector2i(460, 360))
	)
	row.add_child(cards)
	var rules := CheckButton.new()
	rules.text = "Testuj ruchy według kart"
	rules.toggled.connect(func(value: bool):
		game._cancel_grab()
		game.sandbox_rules = value
		game.odswiez_podpowiedzi()
	)
	box.add_child(rules)
	var help := Label.new()
	help.text = "%s: dołóż pole / napraw dziurę · %s: wybij dziurę" % [PozycjaOsobista.keybind_label("space"), PozycjaOsobista.keybind_label("hole")]
	help.add_theme_font_size_override("font_size", 13)
	box.add_child(help)
	_build_collection()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()

func _layout() -> void:
	toolbar.position = Vector2(8, get_viewport().get_visible_rect().size.y - toolbar.size.y - 8)

func _build_collection() -> void:
	collection = AcceptDialog.new()
	collection.title = "Sandbox — aktywne karty"
	collection.get_ok_button().text = "Wróć na planszę"
	add_child(collection)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 280)
	collection.add_child(scroll)
	var box := VBoxContainer.new()
	scroll.add_child(box)
	for id in CardRegistry.all_ids():
		var row := HBoxContainer.new()
		box.add_child(row)
		for color in ["b", "c"]:
			var check := CheckBox.new()
			check.text = "B" if color == "b" else "C"
			check.tooltip_text = "Białe" if color == "b" else "Czarne"
			check.toggled.connect(func(enabled: bool): game.sandbox_set_card(color, id, enabled))
			row.add_child(check)
		var label := Label.new()
		label.text = CardRegistry.display_name(id)
		label.tooltip_text = CardRegistry.description(id)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)

func blocks_board() -> bool:
	return collection.visible or toolbar.get_global_rect().has_point(toolbar.get_global_mouse_position())
