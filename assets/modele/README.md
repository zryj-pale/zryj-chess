# Modele figur (wsad do fotobudki)

Tu wrzucasz modele 3D figur. `scenes/fotobudka.tscn` skanuje ten katalog i renderuje
z nich sprite'y, które rysuje plansza.

## Jak nazywać pliki

Model i jego tekstura mają mieć **tę samą nazwę**:

```
krol.obj      <- geometria (.obj, .glb, .gltf, .fbx)
krol.png      <- tekstura (.png, .jpg, .webp)
```

Fotobudka sama sklei je w materiał — importer .obj w Godocie i tak ignoruje mapy z .mtl,
więc materiał budowany jest w kodzie, z ustawieniami pasującymi do reszty planszy.

Docelowe nazwy odpowiadają kluczom z `scripts/figura.gd`:
`b_pionkler`, `b_skoczek`, `b_goniec`, `b_wieza`, `b_hetman`, `b_krol`
oraz te same z prefiksem `c_` dla czarnych.

## Po wrzuceniu pliku

Godot musi zaimportować nowy asset, zanim da się go wczytać:
otwórz edytor (import robi się sam) albo uruchom

```
Godot_v4.7-stable_win64_console.exe --headless --path . --import
```

Potem odpal `scenes/fotobudka.tscn` (F6) i naciśnij `F`, żeby odświeżyć listę.

W katalogu leży `test_pionek.obj` — wygenerowany, zwykły toczony pionek. Służy tylko
do sprawdzenia, czy fotobudka działa; można go skasować.

## Wyniki

Rendery lądują w `assets/render/`:

- `<nazwa>.png` — gotowy sprite **64×128 px**,
- `<nazwa>_src.png` — pełna rozdzielczość, do dalszej obróbki,
- `<nazwa>_arkusz.png` — 8 ujęć dookoła, do wybrania najlepszego kąta.

`assets/render/fotobudka.json` pamięta wysokość, obrót i oś każdego modelu,
żeby nie ustawiać ich od nowa przy każdym uruchomieniu.

## Dlaczego sprite nie jest kwadratowy

Sprite figury jest billboardem obracanym tylko wokół osi Y, a kamera planszy patrzy
na niego z góry pod 55°. Zmierzone: kwadrat 1×1 kratki rysuje się wtedy jako
200×114 px — jest ściśnięty do 57% wysokości. Figura o wysokości 1 kratki i podstawie
0,6 kratki zajmuje na ekranie ~1,06 kratki w pionie, więc **w kwadrat 1×1 fizycznie
się nie mieści** — dlatego obecne placeholdery są płaskie i przysadziste.

Kadr fotobudki to więc quad 1×2 kratki (sprite 64×128), przy czym powierzchnia pola
jest 0,45 kratki nad dolną krawędzią: podstawa figury rzutuje się *poniżej* pola,
na którym stoi, i bez tego marginesu ucinałby się jej przód.

Plik `.png` na dysku wygląda przez to na rozciągnięty w pionie. Tak ma być —
skrót perspektywiczny planszy ściska go z powrotem.

Wpięcie tego formatu w grę (`figura.tscn`, `figura.gd`, `main.gd`) to osobna zmiana,
opisana na końcu `scripts/fotobudka.gd`. Nie jest jeszcze zrobiona, bo zepsułaby
obecny arkusz `assets/pionkler.png` (siatka komórek 64×64).
