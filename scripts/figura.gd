extends Node3D

@export var typ: String
@export var kolor: String

# ── Dwie drogi, ten sam piksel ──────────────────────────────────────────────
#
# Figury są płaskimi billboardami z jednej komórki assets/pionkler.png - poza
# skoczkiem, który ma model i stoi na planszy jako prawdziwa bryła 3D. Tak czy
# tak rozpikselowanie pochodzi z scripts/warstwa_figur.gd: cała warstwa figur
# jest renderowana w 32 pikselach na kratkę planszy i powiększana filtrem
# nearest, więc obie drogi dają ten sam rozmiar piksela.
#
# Wcześniej figura piekła się do własnego bufora razem z modelem w środku, co
# wymuszało pokazywanie wyniku na billboardzie. Prawdziwa bryła tego nie
# przyjmuje: musi być widziana pod kątem planszy, mieć głębię i zasłanianie
# przez kafelki.
const TYP_Z_MODELEM := "S" # na razie tylko skoczek ma model
const PIECE_Y := 0.5 # main.gd/ustawianie.gd stawiają figurę pół kratki nad płytą
const WYSOKOSC_ATLASU := 64.0 # jedna komórka pionkler.png = jedna kratka

# Node3D nie ma własnego modulate (to pojęcie z 2D), więc rozdzielamy je na to,
# co widać: sprite dostaje modulate, a cieniowany model tint do shadera.
var modulate: Color = Color.WHITE:
	set(value):
		_modulate = value
		_odswiez_zabarwienie()

var _modulate := Color.WHITE

const WSPOLRZEDNE_SPRITE = {
	"b_pionkler" : Rect2(0, 0, 64, 64),
	"b_skoczek" : Rect2(64, 0, 64, 64),
	"b_goniec" : Rect2(128, 0, 64, 64),
	"b_wieza" : Rect2(192, 0, 64, 64),
	"b_hetman" : Rect2(256, 0, 64, 64),
	"b_krol" : Rect2(320, 0, 64, 64),
	"c_pionkler" : Rect2(0, 64, 64, 64),
	"c_skoczek" : Rect2(64, 64, 64, 64),
	"c_goniec" : Rect2(128, 64, 64, 64),
	"c_wieza" : Rect2(192, 64, 64, 64),
	"c_hetman" : Rect2(256, 64, 64, 64),
	"c_krol" : Rect2(320, 64, 64, 64)
	}

const NAZWY = {
	"Sb":"b_skoczek",
	"Gb":"b_goniec",
	"Pb":"b_pionkler",
	"Wb":"b_wieza",
	"Hb":"b_hetman",
	"Kb":"b_krol",
	"Sc":"c_skoczek",
	"Gc":"c_goniec",
	"Pc":"c_pionkler",
	"Wc":"c_wieza",
	"Hc":"c_hetman",
	"Kc":"c_krol"
	}

var _material: ShaderMaterial
var _podstawa_y := 0.0 # world Y płaszczyzny płyty, dla gradientu w shaderze
var _wysokosc := 1.0

func _ready() -> void:
	_posadz_meshe()
	_ustaw_warstwy()
	_ustaw_cien()
	_zastosuj_typ()

# Pozycja figury jest tym, co czyta logika szachowa, więc dryf płyty nie może jej
# ruszać - dlatego przesuwa się tylko zawartość.
func ustaw_lewitacje(offset: Vector3) -> void:
	($Zawartosc as Node3D).position = offset

func promocja(typ_figury) -> void:
	typ = typ_figury
	_zastosuj_typ()

# Figury stoją na warstwie 2: kamera planszy ma tę warstwę wykluczoną, a kamera
# warstwy figur widzi wyłącznie ją - inaczej każda figura rysowałaby się dwa razy.
func _ustaw_warstwy() -> void:
	var maska := 1 << (WarstwaFigur.WARSTWA_FIGUR - 1)
	for wezel in [$Zawartosc/tekstura, $Zawartosc/Skoczek_punkt]:
		for widoczny in _widoczne(wezel):
			widoczny.layers = maska

func _widoczne(wezel: Node) -> Array[VisualInstance3D]:
	var wynik: Array[VisualInstance3D] = []
	if wezel is VisualInstance3D:
		wynik.append(wezel)
	for dziecko in wezel.get_children():
		wynik.append_array(_widoczne(dziecko))
	return wynik

func _zastosuj_typ() -> void:
	var z_modelem := typ == TYP_Z_MODELEM
	($Zawartosc/Skoczek_punkt as Node3D).visible = z_modelem
	($Zawartosc/tekstura as Sprite3D).visible = not z_modelem
	if not z_modelem:
		var nazwa: String = NAZWY.get(typ + kolor, NAZWY["Pb"])
		($Zawartosc/tekstura as Sprite3D).region_rect = WSPOLRZEDNE_SPRITE[nazwa]
	_ustaw_material()
	_odswiez_zabarwienie()
	# Figury 2D nie rzucają cienia: billboard z wyciętą alfą rzuciłby cały
	# prostokąt, a nie sylwetkę figury.
	for siatka in _siatki($Cien):
		siatka.visible = z_modelem

# Cień rzuca osobna, nigdy nie rysowana kopia bryły (SHADOWS_ONLY), ustawiona w
# tej samej transformacji co mesh w zawartości. Musi stać na warstwie planszy:
# pass cieni widoku planszy respektuje maskę kamery planszy, która warstwę figur
# wyklucza, więc sam mesh nie trafiłby do jej mapy cieni i cień by zniknął.
func _ustaw_cien() -> void:
	var cien := $Cien as Node3D
	if cien == null:
		return
	cien.transform = ($Zawartosc/Skoczek_punkt as Node3D).transform
	for siatka in _siatki(cien):
		siatka.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		siatka.layers = 1

func _odswiez_zabarwienie() -> void:
	var sprite := $Zawartosc/tekstura as Sprite3D
	if sprite != null:
		sprite.modulate = _modulate
	if _material != null:
		_material.set_shader_parameter("tint", _modulate)

# Origin modelu nie leży w jego stopach, więc figura postawiona na PIECE_Y
# wisiałaby pół kratki nad swoim polem. Mierzone z bryły, a nie zakładane.
func _posadz_meshe() -> void:
	var dol := INF
	var gora := -INF
	for siatka in _siatki($Zawartosc):
		var pudelko: AABB = siatka.get_aabb()
		var wzgledem: Transform3D = global_transform.affine_inverse() * siatka.global_transform
		for wierzcholek in 8:
			var punkt: Vector3 = wzgledem * pudelko.get_endpoint(wierzcholek)
			dol = minf(dol, punkt.y)
			gora = maxf(gora, punkt.y)
	if dol == INF:
		return
	# Powierzchnia płyty leży PIECE_Y poniżej origina figury.
	($Zawartosc/Skoczek_punkt as Node3D).position.y -= dol + PIECE_Y
	_wysokosc = maxf(gora - dol, 0.001)
	# Płyta leży na świecie y = 0 (main.gd/ustawianie.gd liczą pole jako
	# Vector3(x, 0, y), a figura stoi PIECE_Y nad nią i dokładnie tyle samo
	# odejmuje mesh), więc podstawa figury jest w y = 0 na każdym polu.
	# Liczone wprost, a nie z global_position: w _ready() figura nie ma jeszcze
	# ustawionej pozycji, bo dodanie do drzewa jest przed przypisaniem position.
	_podstawa_y = 0.0

func _siatki(wezel: Node) -> Array[MeshInstance3D]:
	var wynik: Array[MeshInstance3D] = []
	for dziecko in wezel.get_children():
		if dziecko is MeshInstance3D:
			wynik.append(dziecko)
		wynik.append_array(_siatki(dziecko))
	return wynik

# Shader przyciemnia figurę ku jej własnej podstawie (fałszywe AO, które nadaje
# bryłę modelowi o 92 trójkątach). Musi wiedzieć, gdzie ta podstawa jest, a to
# zależy od modelu, więc jest mierzone. Każda figura dostaje własną kopię
# materiału, bo wspólny z assets/pixelfigury.tres nie pomieści zakresu per model.
func _ustaw_material() -> void:
	if _material == null:
		for siatka in _siatki($Zawartosc):
			var wspoldzielony := siatka.get_surface_override_material(0) as ShaderMaterial
			if wspoldzielony == null:
				continue
			_material = wspoldzielony.duplicate() as ShaderMaterial
			siatka.set_surface_override_material(0, _material)
			break
	if _material == null:
		return
	_material.set_shader_parameter("height_base", _podstawa_y)
	_material.set_shader_parameter("height_top", _podstawa_y + _wysokosc)
	_material.set_shader_parameter("tint", _modulate)
