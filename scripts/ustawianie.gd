extends Node2D

@onready var plansza: TileMapLayer = $TileMapLayer
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var punkty_label: Label = $PunktyLabel

const MAX_PUNKTY := 16
const SZARY_KOLOR := Color(0.55, 0.55, 0.55, 1.0)
const WARTOSCI_FIGUR := {"P": 1, "S": 2, "G": 2, "W": 4, "H": 6, "K": 6}

var figury: Array = []
var dostepne_pola: Array[Vector2i] = []
var dragging := false
var drag_piece_type := ""
var drag_preview = null

func _ready() -> void:
	generacja_pol(1, 4, 6, 6)
	synchronizacja()

func _process(_delta: float) -> void:
	if dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position()
	var punkty := oblicz_punkty()
	progress_bar.value = punkty
	punkty_label.text = str(punkty) + "/" + str(MAX_PUNKTY)
	progress_bar.modulate = SZARY_KOLOR
	punkty_label.modulate = SZARY_KOLOR

func _on_piece_selected(typ: String) -> void:
	drag_piece_type = typ
	dragging = true
	if drag_preview:
		drag_preview.queue_free()
	drag_preview = preload("res://scenes/figura.tscn").instantiate()
	drag_preview.typ = typ
	drag_preview.kolor = "b"
	drag_preview.top_level = true
	drag_preview.modulate = Color(0.55, 0.55, 0.55, 0.7)
	drag_preview.get_node("tekstura/Area2D").monitoring = false
	drag_preview.get_node("tekstura/Area2D").monitorable = false
	add_child(drag_preview)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if dragging:
		var pole: Vector2i = plansza.local_to_map(get_global_mouse_position())
		if pole_na_planszy(pole) and not stoi_figura(pole) and can_place(drag_piece_type):
			dodaj(drag_piece_type, pole)
			PozycjaOsobista.ustawienie.append([drag_piece_type, pole])
		_cancel_drag()
		return
	var figura = najechana_figura()
	if figura:
		usun_figure(figura)

func _cancel_drag() -> void:
	dragging = false
	drag_piece_type = ""
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func dodaj(typ: String, pole: Vector2i) -> void:
	var figura = preload("res://scenes/figura.tscn").instantiate()
	figura.typ = typ
	figura.kolor = "b"
	figura.modulate = SZARY_KOLOR
	add_child(figura)
	figury.append(figura)
	figura.global_position = plansza.map_to_local(pole)

func usun_figure(figura) -> void:
	var pole: Vector2i = pozycja(figura)
	for i in range(PozycjaOsobista.ustawienie.size() - 1, -1, -1):
		var ustawienie = PozycjaOsobista.ustawienie[i]
		if ustawienie[0] == figura.typ and ustawienie[1] == pole:
			PozycjaOsobista.ustawienie.remove_at(i)
			break
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zakaz.play()

func oblicz_punkty() -> int:
	var wynik := 0
	for ustawienie in PozycjaOsobista.ustawienie:
		wynik += WARTOSCI_FIGUR.get(ustawienie[0], 0)
	return wynik

func can_place(typ: String) -> bool:
	if oblicz_punkty() + WARTOSCI_FIGUR.get(typ, 0) <= MAX_PUNKTY:
		return true
	$dzwiek/zakaz.play()
	return false

func ma_krola() -> bool:
	for ustawienie in PozycjaOsobista.ustawienie:
		if ustawienie[0] == "K":
			return true
	return false

func najechana_figura():
	for figura in figury:
		if figura.mysz:
			return figura
	return null

func pozycja(figura) -> Vector2i:
	return plansza.local_to_map(figura.global_position)

func stoi_figura(pole: Vector2i):
	for figura in figury:
		if pozycja(figura) == pole:
			return figura
	return null

func pole_na_planszy(pole: Vector2i) -> bool:
	return pole in dostepne_pola

func generacja_pol(x: int, y: int, width: int, height: int) -> void:
	for w in range(x, width + 1):
		for h in range(y, height + 1):
			dostepne_pola.append(Vector2i(w, h))

func reset() -> void:
	for figura in figury:
		figura.queue_free()
	figury.clear()

func synchronizacja() -> void:
	reset()
	for ustawienie in PozycjaOsobista.ustawienie:
		dodaj(ustawienie[0], ustawienie[1])

func _on_reset_pressed() -> void:
	_cancel_drag()
	reset()
	PozycjaOsobista.ustawienie.clear()

func _on_menu_pressed() -> void:
	if not ma_krola():
		$dzwiek/zakaz.play()
		return
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")
