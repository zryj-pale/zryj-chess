extends Node2D

@onready var plansza = $TileMapLayer
@export var dodawanie_pol = false

var wartosci_figur = {
	"P":1,
	"S":2,
	"G":2,
	"W":4,
	"H":6,
	"K":6
}
const MAX_PUNKTY = 16



enum stany{
	IDLE,
	GRAB,
	SELECT
}
var stan := stany.IDLE

var figury = []
var chwycona = null
var poczatkowe_pole = null
var dostepne_pola = []

var wybrana = null
var dragging = false
var drag_piece_type = null
var drag_preview = null

func _ready() -> void:
	generacja_pol(1,4,6,6)

func _on_piece_selected(typ: String):
	drag_piece_type = typ
	dragging = true
	create_drag_preview(typ)

func create_drag_preview(typ: String):
	if drag_preview:
		drag_preview.queue_free()
	drag_preview = preload("res://scenes/figura.tscn").instantiate()
	drag_preview.typ = typ
	drag_preview.kolor = "b"
	drag_preview.top_level = true
	drag_preview.modulate = Color(1, 1, 1, 0.7)
	drag_preview.get_node("tekstura/Area2D").monitoring = false
	drag_preview.get_node("tekstura/Area2D").monitorable = false
	add_child(drag_preview)

@onready var progress_bar = $ProgressBar
@onready var punkty_label = $PunktyLabel

func _process(_delta: float) -> void:
	if dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position()
	var punkty = oblicz_punkty()
	progress_bar.value = punkty
	punkty_label.text = str(punkty) + "/" + str(MAX_PUNKTY)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging:
			var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
			if wskazane_pole.x >= 0 and wskazane_pole.x <= 7 and wskazane_pole.y >= 0 and wskazane_pole.y <= 7 and stoi_figura(wskazane_pole) == null and can_place(drag_piece_type):
				dodaj(drag_piece_type, "b", wskazane_pole)
				zapisz_figure(drag_piece_type, wskazane_pole)
			dragging = false
			drag_piece_type = null
			if drag_preview:
				drag_preview.queue_free()
				drag_preview = null
		else:
			var figura = najechana_figura()
			if figura and figura.kolor == "b":
				usun_figure(figura)

func usun_figure(figura):
	var pole = pozycja(figura)
	usun_z_pamieci(figura.typ, pole)
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zakaz.play()

func usun_z_pamieci(typ: String, pole: Vector2i):
	for i in range(PozycjaOsobista.ustawienia_bialych.size() - 1, -1, -1):
		var ustawienie = PozycjaOsobista.ustawienia_bialych[i]
		if ustawienie[0] == typ and ustawienie[1] == pole:
			PozycjaOsobista.ustawienia_bialych.remove_at(i)
			break

func zapisz_figure(typ: String, pole: Vector2i):
	PozycjaOsobista.ustawienia_bialych.append([typ, pole])

func oblicz_punkty() -> int:
	var punkty = 0
	for ustawienie in PozycjaOsobista.ustawienia_bialych:
		punkty += wartosci_figur.get(ustawienie[0], 0)
	return punkty

func ma_krola() -> bool:
	for ustawienie in PozycjaOsobista.ustawienia_bialych:
		if ustawienie[0] == "K":
			return true
	return false

func can_place(typ: String) -> bool:
	var current_points = oblicz_punkty()
	var piece_points = wartosci_figur.get(typ, 0)
	if current_points + piece_points > MAX_PUNKTY:
		$dzwiek/zakaz.play()
		return false
	return true

func najechana_figura():
	for figura in figury:
		if figura.mysz:
			return figura
	return null

func chwyc(figura):
	chwycona = figura
	poczatkowe_pole = plansza.local_to_map(chwycona.global_position)
	chwycona.top_level = true

func stan_idle(wskazane_pole):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if najechana_figura()and najechana_figura().kolor == "b":
			chwyc(najechana_figura())
			stan = stany.GRAB

func stan_grab(wskazane_pole):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		chwycona.global_position = get_global_mouse_position()
		return
	puszczenie(wskazane_pole)

func stan_select(wskazane_pole):
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	stan = stany.IDLE

func puszczenie(wskazane_pole):
	if wskazane_pole == poczatkowe_pole:
		wybrana = chwycona
		wybrana.global_position = plansza.map_to_local(poczatkowe_pole)
		stan = stany.SELECT
		stan = stany.IDLE
	else:
		$dzwiek/zakaz.play()
		chwycona.global_position = plansza.map_to_local(poczatkowe_pole)
		stan = stany.IDLE
	chwycona.top_level = false
	chwycona = null


func pozycja(figura):
	return plansza.local_to_map(figura.global_position)

func dodaj(typ_figury, kolor, pole:Vector2i):
	var figura = preload("res://scenes/figura.tscn").instantiate()
	figura.typ = typ_figury
	figura.name = typ_figury
	figura.kolor = kolor
	add_child(figura)
	figury.append(figura)
	figura.global_position = plansza.map_to_local(pole)

func pole_na_planszy(pole:Vector2i):
	if pole in dostepne_pola:
		return true
	return false

func stoi_figura(pole:Vector2i, wykluczona=null):
	for figura in figury:
		if figura.global_position == plansza.map_to_local(pole) and figura != wykluczona:
			return figura

func generacja_pol(x,y,width,height):
	for w in range(x,width+1):
		for h in range(y,height+1):
			dostepne_pola.append(Vector2i(w, h))

func reset():
	for figura in figury:
		figura.queue_free()
	figury.clear()

func _on_reset_pressed() -> void:
	reset()
	PozycjaOsobista.ustawienia_bialych.clear()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

func synchronizacja():
	reset()
	for figura in PozycjaOsobista.ustawienia_bialych:
		var pos = figura[1]
		var pole = pos if pos is Vector2i else Vector2i(pos[0], pos[1])
		dodaj(figura[0], "b", pole)
	$PieceMenu.create_menu()
