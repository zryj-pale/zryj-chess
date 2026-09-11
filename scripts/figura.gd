extends Node3D

@export var typ: String
@export var kolor: String

# ── Dwie drogi, ten sam piksel ──────────────────────────────────────────────
#
# Figury są płaskimi billboardami z jednej komórki assets/pionkler.png - poza
# skoczkiem, który ma modele i stoi na planszy jako prawdziwa bryła 3D. Tak czy
# tak rozpikselowanie pochodzi z scripts/warstwa_figur.gd: cała warstwa figur
# jest renderowana w 32 pikselach na kratkę planszy i powiększana filtrem
# nearest, więc obie drogi dają ten sam rozmiar piksela.
#
# Skoczek ma dwa modele, biały i czarny (assets/skoczek bialy.glb, skoczek
# czarny.glb). Różni je wbudowana tekstura drewna, więc o wyborze decyduje kolor
# figury. Oba leżą w scenie i przełącza je widoczność.
const TYP_Z_MODELEM := "S" # na razie tylko skoczek ma modele
const PIECE_Y := 0.5 # main.gd/ustawianie.gd stawiają figurę pół kratki nad płytą
const WYSOKOSC_ATLASU := 64.0 # jedna komórka pionkler.png = jedna kratka
const MATERIAL_WZOR := preload("res://assets/pixelfigury.tres")

# Node3D nie ma własnego modulate (to pojęcie z 2D), więc rozdzielamy je na to,
# co widać: sprite dostaje modulate, a cieniowane modele tint do shadera.
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

# Siatka -> własna kopia materiału (tint i zakres gradientu są per figura).
var _materialy := {}
var _wysokosc := 1.0

func _ready() -> void:
	_ustaw_warstwy()
	_posadz_modele()
	_ustaw_materialy()
	_zastosuj_typ()

# Pozycja figury jest tym, co czyta logika szachowa, więc dryf płyty nie może jej
# ruszać - dlatego przesuwa się tylko zawartość.
func ustaw_lewitacje(offset: Vector3) -> void:
	($Zawartosc as Node3D).position = offset

func promocja(typ_figury) -> void:
	typ = typ_figury
	_zastosuj_typ()

func _modele() -> Array[Node3D]:
	return [$Zawartosc/SkoczekBialy, $Zawartosc/SkoczekCzarny]

# Czarny kolor dostaje model czarny, każdy inny biały - figura nigdy nie zostaje
# bez bryły, nawet gdyby kiedyś doszedł typ bez własnego modelu.
func model_dla(typ_figury: String, kolor_figury: String) -> Node3D:
	if typ_figury != TYP_Z_MODELEM:
		return null
	return $Zawartosc/SkoczekCzarny if kolor_figury == "c" else $Zawartosc/SkoczekBialy

func _zastosuj_typ() -> void:
	var model := model_dla(typ, kolor)
	for wezel in _modele():
		wezel.visible = wezel == model
	($Zawartosc/tekstura as Sprite3D).visible = model == null
	if model == null:
		var nazwa: String = NAZWY.get(typ + kolor, NAZWY["Pb"])
		($Zawartosc/tekstura as Sprite3D).region_rect = WSPOLRZEDNE_SPRITE[nazwa]
	_ustaw_cien(model)
	_odswiez_zabarwienie()

# Figury stoją na warstwie 2: kamera planszy ma tę warstwę wykluczoną, a kamera
# warstwy figur widzi wyłącznie ją - inaczej każda figura rysowałaby się dwa razy.
func _ustaw_warstwy() -> void:
	var maska := 1 << (WarstwaFigur.WARSTWA_FIGUR - 1)
	for wezel in [$Zawartosc/tekstura, $Zawartosc/SkoczekBialy, $Zawartosc/SkoczekCzarny]:
		for widoczny in _widoczne(wezel):
			widoczny.layers = maska

func _widoczne(wezel: Node) -> Array[VisualInstance3D]:
	var wynik: Array[VisualInstance3D] = []
	if wezel is VisualInstance3D:
		wynik.append(wezel)
	for dziecko in wezel.get_children():
		wynik.append_array(_widoczne(dziecko))
	return wynik

# Origin modelu nie leży w jego stopach, więc figura postawiona na PIECE_Y
# wisiałaby pół kratki nad swoim polem. Mierzone z bryły i wyrównywane dla
# każdego modelu osobno, żeby podmiana modelu nie przesuwała figury.
func _posadz_modele() -> void:
	var najwyzsza := 0.0
	for model in _modele():
		var dol := INF
		var gora := -INF
		for siatka in _siatki(model):
			var pudelko: AABB = siatka.get_aabb()
			var wzgledem: Transform3D = global_transform.affine_inverse() * siatka.global_transform
			for wierzcholek in 8:
				var punkt: Vector3 = wzgledem * pudelko.get_endpoint(wierzcholek)
				dol = minf(dol, punkt.y)
				gora = maxf(gora, punkt.y)
		if dol == INF:
			continue
		# Powierzchnia płyty leży PIECE_Y poniżej origina figury.
		(model as Node3D).position.y -= dol + PIECE_Y
		najwyzsza = maxf(najwyzsza, gora - dol)
	if najwyzsza > 0.0:
		_wysokosc = najwyzsza

func _siatki(wezel: Node) -> Array[MeshInstance3D]:
	var wynik: Array[MeshInstance3D] = []
	for dziecko in wezel.get_children():
		if dziecko is MeshInstance3D:
			wynik.append(dziecko)
		wynik.append_array(_siatki(dziecko))
	return wynik

# Każdy model dostaje własną kopię shadera rozpikselowującego. Tekstura nie jest
# wpisana na sztywno: czytamy ją z materiału, który przyniósł sam model (glTF
# wstawia tam swoje drewno), więc podmiana modelu wystarcza, żeby zmienił się
# kolor figury - shader zostaje ten sam.
func _ustaw_materialy() -> void:
	for model in _modele():
		for siatka in _siatki(model):
			var material := MATERIAL_WZOR.duplicate() as ShaderMaterial
			var zrodlo: Material = null
			if siatka.mesh != null and siatka.mesh.get_surface_count() > 0:
				zrodlo = siatka.mesh.surface_get_material(0)
			var tekstura: Texture2D = null
			if zrodlo is StandardMaterial3D:
				tekstura = (zrodlo as StandardMaterial3D).albedo_texture
			material.set_shader_parameter("use_texture", tekstura != null)
			if tekstura != null:
				material.set_shader_parameter("albedo_texture", tekstura)
			siatka.set_surface_override_material(0, material)
			_materialy[siatka] = material
	_ustaw_zakres_wysokosci()

# Shader przyciemnia figurę ku jej własnej podstawie (fałszywe AO, które nadaje
# bryłę modelowi o 92 trójkątach). Płyta leży na świecie y = 0 (main.gd
# i ustawianie.gd liczą pole jako Vector3(x, 0, y), a figura stoi PIECE_Y nad nią
# i dokładnie tyle samo odejmuje model), więc podstawa jest w y = 0 na każdym
# polu. Liczone wprost, a nie z global_position: w _ready() figura nie ma jeszcze
# ustawionej pozycji, bo dodanie do drzewa jest przed przypisaniem position.
func _ustaw_zakres_wysokosci() -> void:
	for siatka in _materialy:
		var material: ShaderMaterial = _materialy[siatka]
		material.set_shader_parameter("height_base", 0.0)
		material.set_shader_parameter("height_top", maxf(_wysokosc, 0.001))

func _odswiez_zabarwienie() -> void:
	var sprite := $Zawartosc/tekstura as Sprite3D
	if sprite != null:
		sprite.modulate = _modulate
	for siatka in _materialy:
		var material: ShaderMaterial = _materialy[siatka]
		material.set_shader_parameter("tint", _modulate)

# Cień rzuca osobna, nigdy nie rysowana kopia bryły (SHADOWS_ONLY) na warstwie
# planszy. Musi być przebudowana przy każdej zmianie modelu, żeby sylwetka cienia
# zgadzała się z tym, co widać. Kopie siedzą w Zawartości, więc jadą razem
# z lewitacją płyty.
func _ustaw_cien(model: Node3D) -> void:
	var cien := $Zawartosc/Cien as Node3D
	for dziecko in cien.get_children():
		dziecko.queue_free()
	if model == null:
		return
	for siatka in _siatki(model):
		var kopia := MeshInstance3D.new()
		kopia.mesh = siatka.mesh
		kopia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		kopia.layers = 1
		cien.add_child(kopia)
		# Transformacja GLOBALNA, a nie lokalna mesha: mesh siedzi wewnątrz
		# modelu, który ma własną skalę 0.04, więc skopiowanie samego jego
		# transformu dawało cień 25 razy za duży - zalewał całą planszę.
		# Rodzicem jest Zawartość, więc kopia jedzie razem z lewitacją płyty.
		kopia.global_transform = siatka.global_transform
