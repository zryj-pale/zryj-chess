extends Node2D

@onready var plansza = $TileMapLayer

var figury = []
var chwycona = null
var poczatkowe_pole = null
var dostepne_pola = []
var kolor_posuniecia = null
var znaczniki = []
const KOLORY_ZNACZNIKOW = {
	0:Color(0.0, 1.0, 0.0, 1.0),
	1:Color(1.0, 1.0, 0.0, 1.0)
}
var wybrana = null

const OKNO = preload("uid://dcnl4l5bu5ucc")
const ZNACZNIK = preload("uid://bug72ag1gmt76")

func _ready() -> void:
	generacja_pol(6)
	domyslne_ustawienie()
	losowanie()

func najechana_figura():
	for figura in figury:
		if figura.mysz:
			return figura
	return null

func chwyc(figura):
	chwycona = figura
	poczatkowe_pole = plansza.local_to_map(chwycona.global_position)
	usun_znaczniki(null, 0)
	dodaj_znacznik(poczatkowe_pole, 0)
	chwycona.top_level = true

func _process(_delta: float) -> void:
	var docelowe_pole = plansza.local_to_map(get_global_mouse_position())
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not chwycona:
			if najechana_figura() and najechana_figura().kolor == kolor_posuniecia:
				chwyc(najechana_figura())
		else:
			chwycona.global_position = get_global_mouse_position()
		if not chwycona and wybrana and moze_ruszyc(wybrana, poczatkowe_pole, docelowe_pole):
			ruch(wybrana, docelowe_pole)
			usun_znaczniki()
			dodaj_znacznik(poczatkowe_pole, 1)
			dodaj_znacznik(docelowe_pole, 1)
			wybrana = null
	elif chwycona: #jesli puszczona
		if docelowe_pole == poczatkowe_pole:
			wybrana = chwycona
			wybrana.global_position = plansza.map_to_local(poczatkowe_pole)
		elif moze_ruszyc(chwycona, poczatkowe_pole, docelowe_pole):
			ruch(chwycona, docelowe_pole)
			usun_znaczniki()
			dodaj_znacznik(poczatkowe_pole, 1)
			dodaj_znacznik(docelowe_pole, 1)
			wybrana = null
		else:
			if poczatkowe_pole != docelowe_pole:
				$dzwiek/zakaz.play()
			chwycona.global_position = plansza.map_to_local(poczatkowe_pole)
		chwycona.top_level = false
		chwycona = null

func moze_ruszyc(figura, _poczatkowe_pole, docelowe_pole):
	figura.global_position = plansza.map_to_local(docelowe_pole)
	if czy_szach(kolor_posuniecia, stoi_figura(docelowe_pole, figura)):
		figura.global_position = plansza.map_to_local(_poczatkowe_pole)
		return false
	figura.global_position = plansza.map_to_local(_poczatkowe_pole)
	if docelowe_pole in mozliwe_ruchy(figura, _poczatkowe_pole):
		if stoi_figura(docelowe_pole) == null or stoi_figura(docelowe_pole).kolor != figura.kolor:
			return true
	return false
	
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("space"):
		dodaj_pole(plansza.local_to_map(get_global_mouse_position()))
	
func pozycja(figura):
	return plansza.local_to_map(figura.global_position)

func ruch(figura, pole:Vector2i):
	koniec_tury()
	if stoi_figura(pole) != null:
		zbicie(stoi_figura(pole))
	figura.global_position = plansza.map_to_local(pole)
	if moze_promowac(figura):
		figura.promocja("H")
	$dzwiek/ruch.play()
	if czy_szach("b") or czy_szach("c"):
		$dzwiek/szach.play()
		if legalne_posuniecia(get_king(kolor_posuniecia)) == []:
			koniec_gry(kolor_posuniecia)
	elif czy_pat(kolor_posuniecia):
		koniec_gry()

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

func zbicie(figura):
	figury.erase(figura)
	figura.queue_free()
	$dzwiek/zbicie.play()

func stoi_figura(pole:Vector2i, wykluczona=null):
	for figura in figury:
		if figura.global_position == plansza.map_to_local(pole) and figura != wykluczona:
			return figura

func generacja_pol(rozmiar:int):
	for x in range(1,rozmiar+1):
		for y in range(1,rozmiar+1):
			dostepne_pola.append(Vector2i(x, y))

func dodaj_pole(pole:Vector2i):
	if pole[0] in range(0,8) and pole[1] in range(0,8):
		if pole in dostepne_pola:
			return 0
	plansza.set_cell(pole, 0, pole)
	dostepne_pola.append(pole)

func koniec_tury():
	if kolor_posuniecia == "b":
		kolor_posuniecia = "c"
	else:
		kolor_posuniecia = "b"

func czy_szach(kolor_krola, wykluczona=null):
	for figura in figury:
		if figura != wykluczona:
			for mozliwy_ruch in mozliwe_ruchy(figura, pozycja(figura)):
				if pozycja(get_king(kolor_krola)) == mozliwy_ruch and kolor_krola != figura.kolor:
					return true
	return false

func drugi_kolor(kolor):
	if kolor == "b":
		return "c"
	return "b"

func get_king(kolor):
	for figura in figury:
		if figura.typ == "K" and figura.kolor == kolor:
			return figura

func domyslne_ustawienie():
	dodaj("S", "b", Vector2i(2, 5))
	dodaj("S", "b", Vector2i(4, 5))
	dodaj("W", "b", Vector2i(3, 5))
	dodaj("K", "b", Vector2i(2, 6))
	
	dodaj("S", "c", Vector2i(2, 2))
	dodaj("K", "c", Vector2i(2,1))
	dodaj("H", "c", Vector2i(1,1))

func mozliwe_ruchy(figura, pozycja_figury=pozycja(figura)):
	var wynik = []
	var RUCHY_SKOCZKA = [
		Vector2i(1,2),
		Vector2i(-1,2),
		Vector2i(1,-2),
		Vector2i(-1,-2),
		Vector2i(2,1),
		Vector2i(-2,1),
		Vector2i(2,-1),
		Vector2i(-2,-1),]
	var KIERUNKI_GONCA = [
		Vector2i(1,1),
		Vector2i(-1,1),
		Vector2i(1,-1),
		Vector2i(-1,-1)]
	var KIERUNKI_WIEZY = [
		Vector2i(1,0),
		Vector2i(0,1),
		Vector2i(-1,0),
		Vector2i(0,-1)]
	
	match figura.typ:
		"S":
			for pole in RUCHY_SKOCZKA:
				if pole_na_planszy(pozycja_figury+pole):
					wynik.append(pozycja_figury+pole)
		"G":
			for kierunek in KIERUNKI_GONCA:
				var i = 1
				while pole_na_planszy(pozycja_figury+kierunek*i):
					wynik.append(pozycja_figury+kierunek*i)
					if stoi_figura((pozycja_figury+kierunek*i)):
						break
					i += 1
		"W":
			for kierunek in KIERUNKI_WIEZY:
				var i = 1
				while pole_na_planszy(pozycja_figury+kierunek*i):
					wynik.append(pozycja_figury+kierunek*i)
					if stoi_figura((pozycja_figury+kierunek*i)):
						break
					i += 1
		"K":
			for kierunek in KIERUNKI_WIEZY:
				if pole_na_planszy(pozycja_figury+kierunek):
					wynik.append(pozycja_figury+kierunek)
			for kierunek in KIERUNKI_GONCA:
				if pole_na_planszy(pozycja_figury+kierunek):
					wynik.append(pozycja_figury+kierunek)

		"P":
			if figura.kolor == "b":
				if not stoi_figura(pozycja_figury+Vector2i(0,-1)):
					wynik.append(pozycja_figury+Vector2i(0,-1))
				if stoi_figura(pozycja_figury+Vector2i(1,-1)):
					wynik.append(pozycja_figury+Vector2i(1,-1))
				if stoi_figura(pozycja_figury+Vector2i(-1,-1)):
					wynik.append(pozycja_figury+Vector2i(-1,-1))
			else:
				if not stoi_figura(pozycja_figury+Vector2i(0,1)):
					wynik.append(pozycja_figury+Vector2i(0,1))
				if stoi_figura(pozycja_figury+Vector2i(1,1)):
					wynik.append(pozycja_figury+Vector2i(1,1))
				if stoi_figura(pozycja_figury+Vector2i(-1,1)):
					wynik.append(pozycja_figury+Vector2i(-1,1))
				
		"H":
			for kierunek in KIERUNKI_WIEZY:
				var i = 1
				while pole_na_planszy(pozycja_figury+kierunek*i):
					wynik.append(pozycja_figury+kierunek*i)
					if stoi_figura((pozycja_figury+kierunek*i)):
						break
					i += 1
			for kierunek in KIERUNKI_GONCA:
				var i = 1
				while pole_na_planszy(pozycja_figury+kierunek*i):
					wynik.append(pozycja_figury+kierunek*i)
					if stoi_figura((pozycja_figury+kierunek*i)):
						break
					i += 1
	return wynik

func legalne_posuniecia(figura):
	var wynik = []
	for posuniecie in mozliwe_ruchy(figura):
		if moze_ruszyc(figura, pozycja(figura), posuniecie):
			wynik.append(posuniecie)
	return wynik

func czy_pat(kolor):
	for figura in figury:
		if figura.kolor == kolor:
			if legalne_posuniecia(figura) != []:
				return false
	return true

func dodaj_znacznik(pole:Vector2i, _typ):
	var instancja = ZNACZNIK.instantiate()
	instancja.global_position = plansza.map_to_local(pole)
	instancja.typ = _typ
	instancja.kolor = KOLORY_ZNACZNIKOW[_typ]
	add_child(instancja)
	znaczniki.append(instancja)

func usun_znaczniki(pole_znacznika=null, _typ=null):
	if pole_znacznika != null:
		for znacznik in znaczniki:
			if pozycja(znacznik) == pole_znacznika:
				znacznik.queue_free()
				return 0
	elif _typ != null:
		for znacznik in znaczniki:
			if is_instance_valid(znacznik) and znacznik.typ == _typ:
				znacznik.queue_free()
	else:
		for znacznik in znaczniki:
			if is_instance_valid(znacznik):
				znacznik.queue_free()
		znaczniki.clear()

func koniec_gry(kolor_wygranej=null):
	print("koniec")
	match kolor_wygranej:
		"b":
			print("biale wygrywaja!")
		"c":
			print("czarne wygrywaja!")
		null:
			print("pat!")
	queue_free()

func moze_promowac(figura):
	if figura.typ == "P":
		if figura.kolor == "b" and pozycja(figura)[1]==1:
			return true
		elif figura.kolor == "c" and pozycja(figura)[1]==6:
			return true
	return false

func losowanie():
	var okno:Control = OKNO.instantiate()
	okno.global_position = get_viewport_rect().size/2
	add_child(okno)
	await okno.wynik
	if okno.wyrzucona == "reszka":
		kolor_posuniecia = "c"
	else:
		kolor_posuniecia = "b"
	$"dzwiek/muzyka w tle".play()
