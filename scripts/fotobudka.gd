extends Control

# Fotobudka - the rig that turns a 3D piece model into the flat billboard
# sprite the board actually draws.
#
# Why this lives inside the game instead of in a modelling tool: the sprite is
# not a picture of a model, it is a picture of the model AS THE BOARD CAMERA
# SEES IT. Three things have to agree with the board for the result to read as
# a solid object standing on a square, and all three are project constants:
#
#   * the camera tilt (main.gd's CAMERA_TILT_DEG),
#   * the light directions (board_tile.gd's key and fill), so every piece is
#     lit from the same side as the plates it stands on,
#   * the frame, which is exactly one tile wide, because figura.tscn's Sprite3D
#     is a 64 px region at pixel_size 0.015625 - one tile square in world units.
#
# The bit of geometry that is easy to get wrong: figura.tscn billboards the
# sprite around Y only (billboard = 2), so the quad stays VERTICAL while the
# board camera looks down at it from POCHYLENIE degrees. A vertical quad seen
# from that angle is squashed to cos(POCHYLENIE) of its height - measured, not
# assumed: a 1x1 tile quad renders as 200x114 px where a tile is 200 px wide.
# So the render is taken through a frame that is one tile WIDE but only
# KADR_WYS * cos(POCHYLENIE) of a tile TALL in view-plane units - a short, wide
# image - which is then squeezed into the tall sprite. The board's own
# foreshortening stretches it back out and the piece stands at its true height.
# Rendering through a square frame instead is exactly the "why is my piece
# squat" bug.
#
# That measurement is also why the sprite is NOT square. A piece 1 tile tall
# with a 0.6 tile footprint covers about 0.57 * 1 + 0.82 * 0.6 = 1.06 tiles of
# screen height, because at this angle you see a lot of its top. The 1x1 quad
# the board draws today covers only 0.57 - it physically cannot hold a piece
# with real depth, which is why the placeholder art is flat and squat. So the
# frame here is a quad 1 tile wide and KADR_WYS tiles tall, and the sprite it
# exports is SPRITE x SPRITE_WYS. Wiring that into the board is a separate
# change - see the note at the bottom of this file.
#
# Consequence worth knowing while using it: the preview on screen is the
# undistorted one - it shows what the player will see. The PNG on disk looks
# stretched upwards. That is correct; do not "fix" it.

const KATALOG_MODELI := "res://assets/modele"
const KATALOG_RENDEROW := "res://assets/render"
const PLIK_USTAWIEN := "res://assets/render/fotobudka.json"

# Keep equal to main.gd's CAMERA_TILT_DEG. Baked into the shading, so changing
# one without the other silently un-matches every sprite already exported.
const POCHYLENIE := 55.0
const POCHYLENIE_MIN := 5.0
const POCHYLENIE_MAX := 85.0

const KRATKA := 1.0 # one board tile in world units - main.gd's TILE_SIZE_3D

# The billboard quad the sprite is meant for, in tiles. One wide (so a piece
# never overhangs its square) and KADR_GORA up from the tile surface, plus
# KADR_DOL below it. That bottom margin is not padding: the near edge of a
# piece's base projects BELOW the square it stands on, by (footprint / 2) *
# tan(POCHYLENIE) - at 55 degrees that is 0.71 of the footprint, so a piece
# taking up 0.6 of a tile hangs 0.43 of a tile under its own feet. Without the
# margin the front of every base is sliced off. Total stays 2.0 so the sprite
# lands on a power of two.
const KADR_GORA := 1.55
const KADR_DOL := -0.45
const KADR_WYS := KADR_GORA - KADR_DOL

const SPRITE := 64 # exported sprite width in px - the board's tile is 64 px
const SPRITE_WYS := int(SPRITE * KADR_WYS) # 128 - keeps the texels square
const NADPROBKOWANIE := 8 # render this many times bigger, then downscale
const KROKI_OBROTU := 8 # frames in a full turntable pass

const WYSOKOSC_STARTOWA := 0.8 # model height on load, in tiles
const WYSOKOSC_KROK := 0.02
const WYSOKOSC_MIN := 0.1
const WYSOKOSC_MAX := 2.0

const DYSTANS := 4.0 # camera pull-back; arbitrary for an orthogonal camera
const SZEROKOSC_HUD := 330.0 # room the readout needs before it is worth reserving
const OSIE := [0.0, -90.0, 90.0, 180.0] # up-axis fixes for exports that arrive Z-up

const ROZSZERZENIA_MODELI := ["obj", "glb", "gltf", "fbx", "blend", "escn", "tscn", "res", "tres"]
const ROZSZERZENIA_TEKSTUR := ["png", "jpg", "jpeg", "webp", "tga", "bmp"]

const TLA := [
	Color(0.09, 0.09, 0.11),
	Color(0.62, 0.63, 0.66),
	Color(0.85, 0.16, 0.72), # the classic "is that edge really opaque" magenta
]

@onready var _kontener: SubViewportContainer = $PodgladContainer
@onready var _podglad: SubViewport = $PodgladContainer/Podglad
@onready var _tlo: ColorRect = $tlo
@onready var _etykieta: Label = $hud

var _scena: Node3D
var _obrotnica: Node3D # turntable - only the model spins, so the light stays put
var _ustawienie: Node3D # up-axis fix, uniform scale and the centring offset
var _kamera: Camera3D

var _modele: PackedStringArray = []
var _indeks := 0
var _tekstura_nazwa := ""

var _pochylenie := POCHYLENIE
var _obrot := 0.0
var _wysokosc := WYSOKOSC_STARTOWA
var _os := 0
var _szerokosc_modelu := 0.0 # in tiles, for the overflow warning

var _tlo_indeks := 0
var _ustawienia := {}
var _komunikat := ""
var _zapisuje := false


func _ready() -> void:
	_zbuduj_scene()
	_wczytaj_ustawienia()
	_tlo.color = TLA[_tlo_indeks]
	resized.connect(_dopasuj_podglad)
	_skanuj()
	_ustaw_kamere()
	_wczytaj_model()


# The render target is sized for export quality, not for the window - at the
# default supersampling it is taller than the whole canvas. So the preview is
# scaled to fit, and pushed to the right when there is room for the readout
# beside it rather than on top of it.
func _dopasuj_podglad() -> void:
	var cel := Vector2(_podglad.size)
	if cel.x <= 0.0 or cel.y <= 0.0:
		return
	var skala := minf(1.0, minf(size.x * 0.94 / cel.x, size.y * 0.94 / cel.y))
	var widoczne := cel * skala
	_kontener.scale = Vector2(skala, skala)
	var x := (size.x - widoczne.x) * 0.5
	if size.x - widoczne.x >= SZEROKOSC_HUD * 2.0:
		x = size.x - widoczne.x - 24.0
	_kontener.position = Vector2(x, (size.y - widoczne.y) * 0.5)


# The SubViewport renders its own world and starts out with no lights at all,
# so everything in it would be pure albedo - flat, and with no sense of the
# piece being solid, which is the entire point of modelling it. The key's
# direction is copied from board_tile.gd so a piece and the plate under it
# agree about where the light is coming from; the rim exists to keep the
# silhouette from merging into whatever is behind it on the board.
func _zbuduj_scene() -> void:
	_scena = Node3D.new()
	_scena.name = "scena"
	_podglad.add_child(_scena)

	_obrotnica = Node3D.new()
	_obrotnica.name = "obrotnica"
	_scena.add_child(_obrotnica)

	_ustawienie = Node3D.new()
	_ustawienie.name = "ustawienie"
	_obrotnica.add_child(_ustawienie)

	_kamera = Camera3D.new()
	_kamera.name = "kamera"
	_kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# KEEP_WIDTH plus a viewport whose aspect carries the foreshortening is what
	# makes `size` mean "the frame is this many tiles wide" - see the header.
	_kamera.keep_aspect = Camera3D.KEEP_WIDTH
	_kamera.size = KRATKA
	_kamera.near = 0.01
	_kamera.far = 100.0
	_kamera.current = true
	_scena.add_child(_kamera)

	var klucz := DirectionalLight3D.new()
	klucz.name = "klucz"
	klucz.rotation_degrees = Vector3(-52.0, -34.0, 0.0) # board_tile.gd's key
	klucz.light_energy = 1.1
	klucz.shadow_enabled = false
	_scena.add_child(klucz)

	var wypelnienie := DirectionalLight3D.new()
	wypelnienie.name = "wypelnienie"
	wypelnienie.rotation_degrees = Vector3(-18.0, 146.0, 0.0) # board_tile.gd's fill
	wypelnienie.light_color = Color(0.84, 0.88, 1.0)
	wypelnienie.light_energy = 0.38
	wypelnienie.shadow_enabled = false
	_scena.add_child(wypelnienie)

	var kontur := DirectionalLight3D.new()
	kontur.name = "kontur"
	kontur.rotation_degrees = Vector3(14.0, 172.0, 0.0)
	kontur.light_energy = 0.5
	kontur.shadow_enabled = false
	_scena.add_child(kontur)


# ---------------------------------------------------------------- model files

func _skanuj() -> void:
	_modele.clear()
	var katalog := DirAccess.open(KATALOG_MODELI)
	if katalog == null:
		return
	for plik in katalog.get_files():
		# Only real source files count. The editor keeps a .import sidecar next
		# to every asset and does NOT remove it when the source is deleted, so
		# listing those instead would keep offering models that are long gone
		# (they still load - the imported copy survives in .godot/imported).
		if plik.ends_with(".import") or plik.ends_with(".remap"):
			continue
		if not ROZSZERZENIA_MODELI.has(plik.get_extension().to_lower()):
			continue
		if not _modele.has(plik):
			_modele.append(plik)
	_modele.sort()
	_indeks = clampi(_indeks, 0, maxi(0, _modele.size() - 1))


func _nazwa_modelu() -> String:
	return _modele[_indeks] if _indeks < _modele.size() else ""


func _wczytaj_model() -> void:
	for dziecko in _ustawienie.get_children():
		dziecko.queue_free()
		_ustawienie.remove_child(dziecko)
	_tekstura_nazwa = ""
	_szerokosc_modelu = 0.0

	var nazwa := _nazwa_modelu()
	if nazwa.is_empty():
		_odswiez_hud()
		return

	_zastosuj_ustawienia(nazwa)

	var sciezka := KATALOG_MODELI.path_join(nazwa)
	var zasob := load(sciezka)
	if zasob == null:
		# Almost always a file dropped in while the editor was not looking:
		# without an import pass there is no imported resource to load.
		_komunikat = "nie da sie wczytac %s - uruchom import (F w edytorze lub --import)" % nazwa
		_odswiez_hud()
		return

	var wezel: Node3D = null
	if zasob is Mesh:
		var siatka := MeshInstance3D.new()
		siatka.mesh = zasob
		wezel = siatka
	elif zasob is PackedScene:
		var instancja := (zasob as PackedScene).instantiate()
		wezel = instancja if instancja is Node3D else null
		if wezel == null:
			instancja.queue_free()
	if wezel == null:
		_komunikat = "%s nie zawiera geometrii 3D" % nazwa
		_odswiez_hud()
		return

	_ustawienie.add_child(wezel)
	_nalozy_material(wezel, _znajdz_teksture(nazwa))
	_ustaw_model()
	_komunikat = ""
	_odswiez_hud()


# The texture is paired by name rather than configured, so dropping krol.obj
# and krol.png into the folder is the whole workflow. Godot's .obj importer
# ignores the .mtl's maps anyway, so the material is built here regardless.
func _znajdz_teksture(nazwa: String) -> Texture2D:
	var baza := nazwa.get_basename()
	for rozszerzenie in ROZSZERZENIA_TEKSTUR:
		var sciezka := KATALOG_MODELI.path_join("%s.%s" % [baza, rozszerzenie])
		if ResourceLoader.exists(sciezka):
			_tekstura_nazwa = sciezka.get_file()
			return load(sciezka)
	var katalog := DirAccess.open(KATALOG_MODELI)
	if katalog != null:
		for plik in katalog.get_files():
			if plik.ends_with(".import") or plik.ends_with(".remap"):
				continue
			if not ROZSZERZENIA_TEKSTUR.has(plik.get_extension().to_lower()):
				continue
			if not plik.get_basename().begins_with(baza):
				continue
			var sciezka := KATALOG_MODELI.path_join(plik)
			if ResourceLoader.exists(sciezka):
				_tekstura_nazwa = plik
				return load(sciezka)
	return null


func _nalozy_material(wezel: Node, tekstura: Texture2D) -> void:
	if wezel is MeshInstance3D:
		var material := StandardMaterial3D.new()
		if tekstura != null:
			material.albedo_texture = tekstura
		else:
			material.albedo_color = Color(0.72, 0.70, 0.66)
		material.roughness = 1.0
		material.metallic = 0.0
		# Matte, and there is no environment here to reflect, so a specular lobe
		# would only ever show up as a hotspot sliding across the piece as it
		# turns - which then bakes into one sprite and not the others.
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		# Hand-made exports come back with their winding either way round; a
		# piece rendered inside-out is a confusing thing to debug.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		wezel.material_override = material
	for dziecko in wezel.get_children():
		_nalozy_material(dziecko, tekstura)


# ------------------------------------------------------------------- framing

# Places the model so its base sits at y = 0 and it is centred on the turntable
# axis, scaled so it is `_wysokosc` tiles tall. Scale is per model and kept in
# the settings file rather than fitted to the frame every time: a king SHOULD
# render taller than a pawn, and auto-fitting each one to the frame would make
# the whole set the same size - the one mistake that cannot be fixed later
# without re-rendering everything.
func _ustaw_model() -> void:
	if _ustawienie.get_child_count() == 0:
		return
	var podstawa := Basis.from_euler(Vector3(deg_to_rad(OSIE[_os]), 0.0, 0.0))
	var surowy := _aabb_dzieci(_ustawienie)
	if surowy.size == Vector3.ZERO:
		return
	var obrocony := Transform3D(podstawa, Vector3.ZERO) * surowy
	var skala := (_wysokosc * KRATKA) / maxf(obrocony.size.y, 0.0001)
	var pelna := podstawa.scaled(Vector3.ONE * skala)
	var pudlo := Transform3D(pelna, Vector3.ZERO) * surowy
	_ustawienie.transform = Transform3D(pelna, Vector3(
		-pudlo.get_center().x,
		-pudlo.position.y,
		-pudlo.get_center().z))
	_szerokosc_modelu = pudlo.size.x / KRATKA


func _aabb_dzieci(wezel: Node3D) -> AABB:
	var wynik := AABB()
	var pierwszy := true
	for dziecko in wezel.get_children():
		if dziecko is not Node3D:
			continue
		var lokalne := _aabb_wezla(dziecko)
		if lokalne.size == Vector3.ZERO:
			continue
		var w_rodzicu := (dziecko as Node3D).transform * lokalne
		wynik = w_rodzicu if pierwszy else wynik.merge(w_rodzicu)
		pierwszy = false
	return wynik


func _aabb_wezla(wezel: Node3D) -> AABB:
	var wynik := AABB()
	var pierwszy := true
	if wezel is MeshInstance3D and (wezel as MeshInstance3D).mesh != null:
		wynik = (wezel as MeshInstance3D).get_aabb()
		pierwszy = false
	var dzieci := _aabb_dzieci(wezel)
	if dzieci.size != Vector3.ZERO:
		wynik = dzieci if pierwszy else wynik.merge(dzieci)
	return wynik


# Sizes the render target so its aspect carries the board's foreshortening: one
# tile wide, cos(tilt) of a tile tall. See the header - this is the whole trick.
func _ustaw_kamere() -> void:
	var kat := deg_to_rad(_pochylenie)
	var szerokosc := SPRITE * NADPROBKOWANIE
	# The aspect IS the foreshortening: the quad is KADR_WYS tiles tall in the
	# world but only KADR_WYS * cos(tilt) tiles tall on screen.
	var wysokosc := maxi(1, roundi(szerokosc * KADR_WYS * cos(kat)))
	_podglad.size = Vector2i(szerokosc, wysokosc)
	_kontener.size = Vector2(_podglad.size)
	_dopasuj_podglad()
	# Aim at the middle of the quad, not at the model's feet.
	var srodek := (KADR_GORA + KADR_DOL) * 0.5 * KRATKA
	_kamera.position = Vector3(0.0, srodek, 0.0) + Vector3(0.0, sin(kat), cos(kat)) * DYSTANS
	_kamera.rotation = Vector3(-kat, 0.0, 0.0)


# ---------------------------------------------------------------------- input

func _unhandled_input(zdarzenie: InputEvent) -> void:
	if zdarzenie is InputEventMouseMotion:
		var ruch := zdarzenie as InputEventMouseMotion
		if ruch.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_ustaw_obrot(_obrot + ruch.relative.x * 0.5)
		return

	if zdarzenie is InputEventMouseButton and zdarzenie.pressed:
		match (zdarzenie as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_ustaw_wysokosc(_wysokosc + WYSOKOSC_KROK)
			MOUSE_BUTTON_WHEEL_DOWN:
				_ustaw_wysokosc(_wysokosc - WYSOKOSC_KROK)
		return

	if zdarzenie is not InputEventKey or not zdarzenie.pressed or zdarzenie.echo:
		return
	match (zdarzenie as InputEventKey).keycode:
		KEY_LEFT:
			_ustaw_obrot(_obrot - 5.0)
		KEY_RIGHT:
			_ustaw_obrot(_obrot + 5.0)
		KEY_UP:
			_ustaw_pochylenie(_pochylenie + 1.0)
		KEY_DOWN:
			_ustaw_pochylenie(_pochylenie - 1.0)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_ustaw_wysokosc(_wysokosc + WYSOKOSC_KROK)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_ustaw_wysokosc(_wysokosc - WYSOKOSC_KROK)
		KEY_Q:
			_przelacz_model(-1)
		KEY_E:
			_przelacz_model(1)
		KEY_X:
			_os = (_os + 1) % OSIE.size()
			_ustaw_model()
			_zapamietaj()
			_odswiez_hud()
		KEY_R:
			_obrot = 0.0
			_pochylenie = POCHYLENIE
			_obrotnica.rotation_degrees = Vector3.ZERO
			_ustaw_kamere()
			_zapamietaj()
			_odswiez_hud()
		KEY_G:
			_tlo_indeks = (_tlo_indeks + 1) % TLA.size()
			_tlo.color = TLA[_tlo_indeks]
			_odswiez_hud()
		KEY_F:
			_skanuj()
			_wczytaj_model()
		KEY_S:
			_zapisz_widok()
		KEY_T:
			_zapisz_obrot()
		KEY_ESCAPE:
			get_tree().quit()


func _ustaw_obrot(stopnie: float) -> void:
	_obrot = fposmod(stopnie, 360.0)
	_obrotnica.rotation_degrees = Vector3(0.0, _obrot, 0.0)
	_zapamietaj()
	_odswiez_hud()


func _ustaw_pochylenie(stopnie: float) -> void:
	_pochylenie = clampf(stopnie, POCHYLENIE_MIN, POCHYLENIE_MAX)
	_ustaw_kamere()
	_odswiez_hud()


func _ustaw_wysokosc(tile: float) -> void:
	_wysokosc = clampf(tile, WYSOKOSC_MIN, WYSOKOSC_MAX)
	_ustaw_model()
	_zapamietaj()
	_odswiez_hud()


func _przelacz_model(krok: int) -> void:
	if _modele.is_empty():
		return
	_indeks = posmod(_indeks + krok, _modele.size())
	_wczytaj_model()


# --------------------------------------------------------------------- export

func _zrzut() -> Image:
	# One frame for the transform change to reach the server, one draw to read
	# back - without both, a turntable pass exports the previous angle.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _podglad.get_texture().get_image()


# The resize does two jobs at once: it downsamples the supersampled render to
# the 64 px the board draws, and - because the source is wide and short - it
# stretches the piece back to its true height for the vertical billboard.
func _sprite(surowy: Image) -> Image:
	var wynik := surowy.duplicate() as Image
	wynik.resize(SPRITE, SPRITE_WYS, Image.INTERPOLATE_LANCZOS)
	return wynik


# Whether the piece runs off the frame, read off the render itself rather than
# predicted from the model's bounds: an AABB badly over-estimates a lathed
# piece (its corners are empty air), and the rendered alpha is the exact answer
# to the only question that matters - is anything touching the edge.
func _dotyka_krawedzi(obraz: Image) -> bool:
	var w := obraz.get_width()
	var h := obraz.get_height()
	for x in w:
		if obraz.get_pixel(x, 0).a > 0.5 or obraz.get_pixel(x, h - 1).a > 0.5:
			return true
	for y in h:
		if obraz.get_pixel(0, y).a > 0.5 or obraz.get_pixel(w - 1, y).a > 0.5:
			return true
	return false


func _zapisz_widok() -> void:
	if _zapisuje or _nazwa_modelu().is_empty():
		return
	_zapisuje = true
	var baza := _nazwa_modelu().get_basename()
	_przygotuj_katalog()
	var surowy := await _zrzut()
	surowy.save_png(KATALOG_RENDEROW.path_join("%s_src.png" % baza))
	_sprite(surowy).save_png(KATALOG_RENDEROW.path_join("%s.png" % baza))
	_komunikat = "zapisano %s.png (%dx%d) w %s" % [
		baza, SPRITE, SPRITE_WYS, ProjectSettings.globalize_path(KATALOG_RENDEROW)]
	if _dotyka_krawedzi(surowy):
		_komunikat += "\nUWAGA: figura dotyka krawedzi kadru - obniz wysokosc (-)"
	_zapisuje = false
	_odswiez_hud()


# A full turn, for picking the angle a piece reads best from. The board only
# ever draws one of these (the sprite is Y-billboarded, so it always faces the
# camera), so this is a contact sheet to choose from, not an animation.
func _zapisz_obrot() -> void:
	if _zapisuje or _nazwa_modelu().is_empty():
		return
	_zapisuje = true
	var baza := _nazwa_modelu().get_basename()
	_przygotuj_katalog()
	var zapamietany := _obrot
	var arkusz := Image.create(SPRITE * KROKI_OBROTU, SPRITE_WYS, false, Image.FORMAT_RGBA8)
	for krok in KROKI_OBROTU:
		var kat := 360.0 / KROKI_OBROTU * krok
		_obrotnica.rotation_degrees = Vector3(0.0, kat, 0.0)
		var klatka := _sprite(await _zrzut())
		klatka.save_png(KATALOG_RENDEROW.path_join("%s_%02d.png" % [baza, krok]))
		arkusz.blit_rect(klatka, Rect2i(0, 0, SPRITE, SPRITE_WYS), Vector2i(SPRITE * krok, 0))
	arkusz.save_png(KATALOG_RENDEROW.path_join("%s_arkusz.png" % baza))
	_obrotnica.rotation_degrees = Vector3(0.0, zapamietany, 0.0)
	_komunikat = "zapisano %d ujec + %s_arkusz.png" % [KROKI_OBROTU, baza]
	_zapisuje = false
	_odswiez_hud()


func _przygotuj_katalog() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KATALOG_RENDEROW))


# ----------------------------------------------------------------- settings

# Per-model scale, turn and up-axis survive between runs. Losing them would
# mean re-eyeballing every piece's height against the rest of the set, which is
# the slow part of the job.
func _wczytaj_ustawienia() -> void:
	if not FileAccess.file_exists(PLIK_USTAWIEN):
		return
	var plik := FileAccess.open(PLIK_USTAWIEN, FileAccess.READ)
	if plik == null:
		return
	var dane = JSON.parse_string(plik.get_as_text())
	if dane is Dictionary:
		_ustawienia = dane
		_tlo_indeks = int(_ustawienia.get("_tlo", 0)) % TLA.size()


func _zastosuj_ustawienia(nazwa: String) -> void:
	var wpis = _ustawienia.get(nazwa, {})
	if wpis is not Dictionary:
		wpis = {}
	_wysokosc = clampf(float(wpis.get("wysokosc", WYSOKOSC_STARTOWA)), WYSOKOSC_MIN, WYSOKOSC_MAX)
	_os = int(wpis.get("os", 0)) % OSIE.size()
	_obrot = fposmod(float(wpis.get("obrot", 0.0)), 360.0)
	_obrotnica.rotation_degrees = Vector3(0.0, _obrot, 0.0)


func _zapamietaj() -> void:
	var nazwa := _nazwa_modelu()
	if nazwa.is_empty():
		return
	_ustawienia[nazwa] = {"wysokosc": _wysokosc, "os": _os, "obrot": _obrot}
	_ustawienia["_tlo"] = _tlo_indeks
	_przygotuj_katalog()
	var plik := FileAccess.open(PLIK_USTAWIEN, FileAccess.WRITE)
	if plik != null:
		plik.store_string(JSON.stringify(_ustawienia, "\t"))


# --------------------------------------------------------------------- HUD

func _odswiez_hud() -> void:
	var wiersze: Array[String] = []
	if _modele.is_empty():
		wiersze.append("brak modeli w %s" % ProjectSettings.globalize_path(KATALOG_MODELI))
		wiersze.append("wrzuc tam .obj (albo .glb) i teksture o tej samej nazwie, potem F")
	else:
		wiersze.append("model: %s   (%d/%d)   [Q/E]" % [
			_nazwa_modelu(), _indeks + 1, _modele.size()])
		wiersze.append("tekstura: %s" % (_tekstura_nazwa if not _tekstura_nazwa.is_empty() else "brak - szary material"))
		wiersze.append("wysokosc: %.2f kratki   [kolko myszy / +-]" % _wysokosc)
		wiersze.append("obrot: %.0f%s   [przeciagnij LPM / <- ->]" % [_obrot, char(0x00B0)])
		wiersze.append("pochylenie: %.0f%s%s   [gora/dol, R = reset]" % [
			_pochylenie, char(0x00B0),
			"  = kat planszy" if is_equal_approx(_pochylenie, POCHYLENIE) else "  UWAGA: plansza ma %.0f" % POCHYLENIE])
		wiersze.append("os pionowa: %+.0f%s   [X]" % [OSIE[_os], char(0x00B0)])
		wiersze.append("kadr: %.0fx%.0f kratki  ->  sprite %dx%d px" % [
			KRATKA, KADR_WYS, SPRITE, SPRITE_WYS])
		if _szerokosc_modelu > 1.0:
			wiersze.append("UWAGA: model jest %.2f kratki szeroki - obcina sie w kadrze" % _szerokosc_modelu)
		if _wysokosc > KADR_GORA:
			wiersze.append("UWAGA: model jest wyzszy niz kadr (%.2f kratki)" % KADR_GORA)
	wiersze.append("")
	wiersze.append("S = zapisz sprite    T = pelny obrot    G = tlo    F = odswiez katalog    Esc = wyjscie")
	if not _komunikat.is_empty():
		wiersze.append(_komunikat)
	_etykieta.text = "\n".join(wiersze)


# What the board still needs, once there are real sprites to switch to. The
# quad this rig renders for is 1 x KADR_WYS tiles with the tile surface
# KADR_DOL below its bottom edge, so figura.tscn/figura.gd/main.gd would move
# from today's square sprite to:
#
#   figura.tscn  region_rect  64 x 128 instead of 64 x 64
#                offset       y = -(SPRITE_WYS * 0.5 + KADR_DOL * SPRITE) px,
#                             so the tile surface, not the quad's middle,
#                             lands on the square the piece stands on
#   figura.gd    WSPOLRZEDNE_SPRITE re-laid out for 64 x 128 cells
#   main.gd      PIECE_HEIGHT = KADR_GORA, so the camera keeps the tallest
#                piece's crown in frame
#
# Deliberately not done yet: it would break the placeholder sheet the game
# currently draws (assets/pionkler.png is a grid of 64 x 64 cells) for as long
# as there are no rendered pieces to replace it with.
