extends Node2D

@onready var plansza = $TileMapLayer
@export var dodawanie_pol = false

var wartosci_figur = {
	"P":1,
	"S":2,
	"G":2,
	"W":4,
	"H":6,
	"K":0
}



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
var kolor_posuniecia = "b"

var wybrana = null

func _ready() -> void:
	print(int("b"))
	generacja_pol(1,4,6,6)

func najechana_figura():
	for figura in figury:
		if figura.mysz:
			return figura
	return null

func chwyc(figura):
	chwycona = figura
	poczatkowe_pole = plansza.local_to_map(chwycona.global_position)
	chwycona.top_level = true

func _process(_delta: float) -> void:
	#get_tree().change_scene_to_file("res://scenes/main.tscn")
	var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
	#match stan:
		#stany.IDLE:
			#stan_idle(wskazane_pole)
		#stany.GRAB:
			#stan_grab(wskazane_pole)
		#stany.SELECT:
			#stan_select(wskazane_pole)

func stan_idle(wskazane_pole):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if najechana_figura()and najechana_figura().kolor == kolor_posuniecia:
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


func _submitted(new_text: String) -> void:
	var operacja = sprawdzanie_tekstu(new_text)
	if operacja != null and Vector2i(operacja[1], operacja[2]) in dostepne_pola:
		dodaj(operacja[0], kolor_posuniecia, Vector2i(operacja[1],operacja[2]))
		if kolor_posuniecia == "b":
			PozycjaOsobista.ustawienia_bialych.append([operacja[0], Vector2i(operacja[1],operacja[2])])
		else:
			PozycjaOsobista.ustawienia_czarnych.append([operacja[0], Vector2i(operacja[1],operacja[2])])
	print(PozycjaOsobista.ustawienia_bialych)
	$LineEdit.text = ""
	$LineEdit.editable = true

func sprawdzanie_tekstu(tekst):
	var figura = ""
	var x = null
	var y = null
	for litera in tekst:
		#if figura != "" and x and y:
			#return [figura.to_upper(),x,y]
		if litera.to_upper() in wartosci_figur:
			figura = litera
		elif int(litera) != 0:
			if not x:
				x = litera
			else:
				y = litera
	if x and y and figura != "":
		return [figura.to_upper(),int(x),int(y)]
		

func reset():
	for figura in figury:
		figura.queue_free()
	figury.clear()

func _on_reset_pressed() -> void:
	reset()
	PozycjaOsobista.ustawienia_bialych.clear()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")


func _on_zmiana_kolorow_pressed() -> void:
	if kolor_posuniecia == "b":
		kolor_posuniecia = "c"
	else:
		kolor_posuniecia = "b"
	synchronizacja()

func synchronizacja():
	reset()
	if kolor_posuniecia == "b":
		for figura in PozycjaOsobista.ustawienia_bialych:
			dodaj(figura[0], "b", figura[1])
	else:
		for figura in PozycjaOsobista.ustawienia_czarnych:
			dodaj(figura[0], "c", figura[1])
