extends Control

# Card collection screen. Pagination is sized for a large future collection
# (16 cards per page in a 4x4 grid) even though only a handful of cards
# exist today - adding cards to CardRegistry never requires touching this
# screen, pages are derived purely from CardRegistry.all_ids().size().
const CARDS_PER_PAGE := 16
const GRID_COLUMNS := 4
const CARD_SIZE := Vector2(108, 144) # 3:4 aspect ratio

@onready var grid: GridContainer = $Margin/VBox/GridCenter/Grid
@onready var page_label: Label = $Margin/VBox/Footer/PageLabel
@onready var prev_button: Button = $Margin/VBox/Footer/PrevButton
@onready var next_button: Button = $Margin/VBox/Footer/NextButton
@onready var back_button: Button = $Margin/VBox/Header/BackButton

var current_page := 0
var card_buttons: Dictionary = {}

func _ready() -> void:
	grid.columns = GRID_COLUMNS
	back_button.pressed.connect(_on_back_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	_render_page()

func _total_pages() -> int:
	var count := CardRegistry.all_ids().size()
	return maxi(1, ceili(float(count) / float(CARDS_PER_PAGE)))

func _on_prev_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_render_page()

func _on_next_pressed() -> void:
	if current_page < _total_pages() - 1:
		current_page += 1
		_render_page()

func _render_page() -> void:
	for child in grid.get_children():
		child.queue_free()
	card_buttons.clear()
	var ids := CardRegistry.all_ids()
	var start := current_page * CARDS_PER_PAGE
	var end := mini(start + CARDS_PER_PAGE, ids.size())
	for i in range(start, end):
		var id: String = ids[i]
		var button := _make_card_button(id)
		grid.add_child(button)
		card_buttons[id] = button
	var total_pages := _total_pages()
	page_label.text = "Strona %d/%d" % [current_page + 1, total_pages]
	prev_button.disabled = current_page <= 0
	next_button.disabled = current_page >= total_pages - 1
	_refresh_selection()

func _make_card_button(id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.toggle_mode = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = CardRegistry.display_name(id) + "\n\n" + CardRegistry.description(id)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_card_pressed.bind(id))
	return button

func _on_card_pressed(id: String) -> void:
	PozycjaOsobista.wybrana_karta = "" if PozycjaOsobista.wybrana_karta == id else id
	_refresh_selection()

func _refresh_selection() -> void:
	for id in card_buttons:
		var button: Button = card_buttons[id]
		button.button_pressed = PozycjaOsobista.wybrana_karta == id

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ustawianie.tscn")
