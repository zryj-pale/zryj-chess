extends Node2D

@onready var plansza = $TileMapLayer
@export var dodawanie_pol = true


enum stany{
	IDLE,
	GRAB,
	SELECT,
	PLACEMENT
}
var stan := stany.IDLE

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
var bialy_tiles = 2
var czarny_tiles = 2
var w_trakcie_rzucania = false
var _prev_mouse_pressed = false
var my_color = ""

const OKNO = preload("uid://dcnl4l5bu5ucc")
const ZNACZNIK = preload("uid://bug72ag1gmt76")

func _ready() -> void:
	add_to_group("game_main")
	generacja_pol(6)
	if NetworkManager.player_id > 0:
		if NetworkManager.host_is_white:
			my_color = "b" if NetworkManager.is_host else "c"
		else:
			my_color = "c" if NetworkManager.is_host else "b"
		NetworkManager.move_received.connect(_on_network_move)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		ustawienie_z_pozycji()
		kolor_posuniecia = "b"
		$HUD/ZmianaButton.visible = false
	else:
		losowanie()
		ustawienie_z_pozycji()

func _on_network_move(from: Vector2i, to: Vector2i):
	var figura = null
	for f in figury:
		if plansza.local_to_map(f.global_position) == from and f.kolor == kolor_posuniecia:
			figura = f
			break
	if figura:
		ruch(figura, to)

func _on_player_disconnected():
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

func ustawienie_z_pozycji():
	for figura in PozycjaOsobista.ustawienia_bialych:
		var pole = Vector2i(figura[1]) if figura[1] is not Vector2i else figura[1]
		dodaj(figura[0], "b", pole)
	for figura in PozycjaOsobista.ustawienia_czarnych:
		var raw = Vector2i(figura[1]) if figura[1] is not Vector2i else figura[1]
		var pole = Vector2i(raw.x, 7 - raw.y)
		dodaj(figura[0], "c", pole)
	

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
	var wskazane_pole = plansza.local_to_map(get_global_mouse_position())
	match stan:
		stany.IDLE:
			stan_idle(wskazane_pole)
		stany.GRAB:
			stan_grab(wskazane_pole)
		stany.SELECT:
			stan_select(wskazane_pole)
		stany.PLACEMENT:
			stan_placement(wskazane_pole)

func stan_idle(wskazane_pole):
	if NetworkManager.player_id > 0 and kolor_posuniecia != my_color:
		return
	if Input.is_action_just_pressed("space"):
		var tiles_left = bialy_tiles if kolor_posuniecia == "b" else czarny_tiles
		if tiles_left > 0:
			w_trakcie_rzucania = true
			stan = stany.PLACEMENT
			return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if najechana_figura()and najechana_figura().kolor == kolor_posuniecia:
			chwyc(najechana_figura())
			stan = stany.GRAB

func stan_placement(wskazane_pole):
	if Input.is_action_just_pressed("space"):
		w_trakcie_rzucania = false
		stan = stany.IDLE
		return
	var mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_pressed and not _prev_mouse_pressed:
		if not pole_na_planszy(wskazane_pole):
			dodaj_pole(wskazane_pole)
			if kolor_posuniecia == "b":
				bialy_tiles -= 1
			else:
				czarny_tiles -= 1
			w_trakcie_rzucania = false
			stan = stany.IDLE
			$dzwiek/ruch.play()
		else:
			$dzwiek/zakaz.play()
	_prev_mouse_pressed = mouse_pressed

func stan_grab(wskazane_pole):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		chwycona.global_position = get_global_mouse_position()
		return
	puszczenie(wskazane_pole)

func stan_select(wskazane_pole):
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if moze_ruszyc(wybrana, poczatkowe_pole, wskazane_pole):
		ruch(wybrana, wskazane_pole)
	stan = stany.IDLE

func puszczenie(wskazane_pole):
	if wskazane_pole == poczatkowe_pole:
		wybrana = chwycona
		wybrana.global_position = plansza.map_to_local(poczatkowe_pole)
		stan = stany.SELECT
	elif moze_ruszyc(chwycona, poczatkowe_pole, wskazane_pole):
		ruch(chwycona, wskazane_pole)
		stan = stany.IDLE
	else:
		$dzwiek/zakaz.play()
		chwycona.global_position = plansza.map_to_local(poczatkowe_pole)
		stan = stany.IDLE
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
	pass
	
func pozycja(figura):
	return plansza.local_to_map(figura.global_position)

func ruch(figura, pole:Vector2i):
	if NetworkManager.player_id > 0 and figura.kolor != my_color:
		return
	if NetworkManager.player_id > 0:
		NetworkManager.submit_move(plansza.local_to_map(figura.global_position), pole)
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
	if pole[0] < 0 or pole[0] > 7 or pole[1] < 0 or pole[1] > 7:
		return
	if pole in dostepne_pola:
		return
	plansza.set_cell(pole, 0, pole)
	dostepne_pola.append(pole)

func koniec_tury():
	w_trakcie_rzucania = false
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

func get_king(kolor):
	for figura in figury:
		if figura.typ == "K" and figura.kolor == kolor:
			return figura

func domyslne_ustawienie():
	#dodaj("S", "b", Vector2i(2, 5))
	#dodaj("S", "b", Vector2i(4, 5))
	#dodaj("W", "b", Vector2i(3, 5))
	#dodaj("K", "b", Vector2i(2, 6))
	
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
	get_tree().change_scene_to_file("res://scenes/menu glowne.tscn")

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
	await okno.koniec_rzutu
	Engine.time_scale = 1
	if okno.wyrzucona == "reszka":
		kolor_posuniecia = "c"
	else:
		kolor_posuniecia = "b"
	$"dzwiek/muzyka w tle".play()
