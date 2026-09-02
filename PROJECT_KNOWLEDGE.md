# Mini Chess — biblioteka wiedzy projektu

> Cel tego pliku: zachować wspólny kontekst zespołu i ułatwić szybkie wdrożenie człowieka lub asystenta AI. Aktualizuj go po ważnych decyzjach produktowych, zmianach architektury i ukończonych kamieniach milowych.

## Spis treści

1. [Szybki obraz projektu](#1-szybki-obraz-projektu)
2. [Wizja i doświadczenie gracza](#2-wizja-i-doświadczenie-gracza)
3. [Klimat, fabuła i styl wizualny](#3-klimat-fabuła-i-styl-wizualny)
4. [Pętla rozgrywki](#4-pętla-rozgrywki)
5. [Zasady obecnego prototypu](#5-zasady-obecnego-prototypu)
6. [Docelowy system kart](#6-docelowy-system-kart)
7. [Tryby gry](#7-tryby-gry)
8. [Stan implementacji](#8-stan-implementacji)
9. [Architektura techniczna](#9-architektura-techniczna)
10. [Struktura plików](#10-struktura-plików)
11. [Sieć i wdrożenie](#11-sieć-i-wdrożenie)
12. [Znane ograniczenia i ryzyka](#12-znane-ograniczenia-i-ryzyka)
13. [Najbliższe priorytety](#13-najbliższe-priorytety)
14. [Otwarte decyzje](#14-otwarte-decyzje)

---

## 1. Szybki obraz projektu

**Mini Chess** (robocza nazwa: **Zryj Chess**) jest rozwijaną przez dwuosobowy zespół grą strategiczną. Punktem wyjścia są szachy, ale celem nie jest wierna implementacja klasycznej gry. To rozbudowany sandbox szachowy z elementami **roguelike**, własnym składem armii, zmienną planszą i kartami modyfikującymi zasady.

Najkrótsza definicja produktu:

> Szachowy sandbox: gracze budują własne, nieuczciwe kombinacje zasad i próbują przetrwać ich konsekwencje. Klimat i styl wizualny nie są jeszcze ustalone.

Docelowe filary:

- kreatywne budowanie strategii zamiast odtwarzania otwarć;
- czytelna gra taktyczna mimo szalonych efektów;
- dużo synergii między figurami, kartami i planszą;
- tryb online oraz ukryty tryb fabularny;
- zdobywanie nowych kart przez rozgrywkę, nie płatności.

---

## 2. Wizja i doświadczenie gracza

Gracz nie dostaje ustalonej pozycji jak w klasycznych szachach. Przed meczem podejmuje decyzje, które tworzą jego build:

1. Wybiera lub przygotowuje ustawienie własnych figur.
2. Wybiera 2 karty z większej kolekcji.
3. Gra na planszy, której rozmiar i dostępne pola mogą się zmieniać.
4. Wykorzystuje niestandardowe reguły, aby wygrać z przeciwnikiem lub bossem.
5. W kampanii zdobywa kolejne karty do późniejszego użycia.

Gra ma dawać uczucie: „znam szachy, ale świat właśnie przestał przestrzegać ich zasad”.

### Zasada projektowa

**Chaos ma być strategiczny, a nie losowy.** Każda modyfikacja może być zaskakująca, lecz musi być zrozumiała przed wykonaniem ruchu i widoczna na planszy.

---

## 3. Klimat, fabuła i styl wizualny

### Motyw świata i kierunek graficzny

Nieustalone. Wcześniejsza koncepcja klimatu i fabuły (m.in. skojarzenia z zainfekowanym/złośliwym oprogramowaniem) była tylko jednym z rozważanych kierunków i nie jest obecnie przyjęta — zespół nie jest jeszcze pewien estetyki gry. Do czasu decyzji obowiązują tylko stałe elementy wizualne poniżej.

Stałe elementy wizualne, niezależne od finalnego stylu:

- klasyczna siatka szachownicy jako czytelna baza;
- rozpoznawalne figury i wyraźna informacja o turze.

### Nicki i kolor meczu

- Każdy gracz podaje niepusty nick w menu głównym; jest on zapamiętywany lokalnie.
- Nick po przycięciu spacji i zamianie na małe litery jest haszowany SHA-256, a pierwsze trzy bajty hasha wyznaczają stały, nasycony kolor HSV gracza.
- W online nicki są synchronizowane razem z ustawieniem i kartą; host jest białymi, gość czarnymi. W lokalnym prototypie oba kolory używają nicku jednego gracza.
- Tło meczu jest płynną mieszanką obu kolorów. Udziały są dokładnie proporcjonalne do aktualnej wartości figur na planszy (P=1, S/G=2, W=4, H/K=6); przy 0:0 używa mieszanki 50:50. Karty, pola i kaczka nie wpływają na tę wartość.
- Tą samą mieszanką barwione są światła planszy, więc tło i plansza czytają się jako jedna scena, a tracenie materiału widocznie odbiera planszy twój kolor. Kreator armii jest neutralny, więc tam światło zostaje białe.
- Tło menu głównego używa tego samego mechanizmu z jednym kolorem — barwą wygenerowaną z własnego nicku gracza, odświeżaną na żywo przy zapisie nicku.

**Granica:** niezależnie od wybranego stylu, grafika nigdy nie może ukrywać pola, legalnego ruchu, stanu figury ani tury.

---

## 4. Pętla rozgrywki

Docelowa pętla meczu:

```text
Wybór trybu
  → wybór/odblokowanie kart
  → wybór 2 kart na mecz
  → ustawienie armii
  → przygotowanie lub modyfikacja planszy
  → mecz z aktywnymi modyfikatorami
  → wynik, nagrody i postęp
```

### Multiplayer

Główna arena rywalizacji i testowania buildów. Gracze powinni mieć jasny wgląd w karty przeciwnika oraz ich efekty.

### Kampania

Ukryty tryb fabularny z bossami. Służy odkrywaniu świata i odblokowywaniu kart do przyszłych rozgrywek multiplayer. Bossowie powinni wymuszać inne myślenie niż zwykły przeciwnik PvP.

---

## 5. Zasady obecnego prototypu

To są zasady zaimplementowane obecnie; nie są jeszcze pełną, ostateczną specyfikacją gry.

- Plansza startuje jako środkowe **6×6 pól** w granicach pełnego obszaru 8×8.
- Każdy gracz może stworzyć neutralne ustawienie własnych figur, mieszczące się w budżecie 16 punktów.
- W meczu drugi zestaw figur powstaje przez odbicie ustawienia pierwszego.
- Każdy kolor ma 2 dodatkowe pola do dołożenia. Wejście w tryb dokładania pola: `Spacja`.
- Dołożenie pola nie kończy tury; ruch figury kończy turę.
- Zaimplementowano ruchy: pion, skoczek, goniec, wieża, hetman, król.
- Figury można przesuwać zarówno kliknięciem, jak i przeciąganiem; w kreatorze można też przeciągać już ustawione figury.
- Jest bicie, wykrywanie szacha, mata i pata. Walidacja ruchu odbywa się na kopii stanu planszy, bez chwilowego przesuwania widoku figury.
- Kolor z więcej niż jednym królem może tracić króle jak zwykłe figury; standardowa ochrona szachem zaczyna działać natychmiast po pozostawieniu mu jednego króla.
- Przy pojedynczym szachu w pozycji startowej ruch dostaje szachowany kolor. Jeżeli oba pojedyncze króle są szachowane, host losuje pozycje wszystkich figur na planszy 6×6 do czasu uzyskania pozycji bez szacha.
- Promujący się pion daje graczowi wybór figury (hetman/wieża/goniec/skoczek) zamiast automatycznej promocji do hetmana; w online wybór dokonuje wyłącznie posuwający pionem, drugi klient dostaje go jako osobną akcję sieciową.
- Online każdy gracz zawsze widzi swoją połowę planszy u dołu ekranu (gość ma widok lustrzanie odbity względem hosta); w trybie lokalnym nic się nie odbija, bo obaj grający dzielą jeden ekran.
- Roszada i ruch pionem o dwa pola istnieją tylko jako karty (sekcja 8) — poza nimi zasady bazowe nie mają jeszcze roszady, bicia w przelocie ani mechaniki pasowania.

W kreatorze figur:

| Figura | Koszt |
| --- | ---: |
| Pion | 1 |
| Skoczek | 2 |
| Goniec | 2 |
| Wieża | 4 |
| Hetman | 6 |
| Król | 6 |

---

## 6. Docelowy system kart

Przed rozgrywką każdy gracz wybiera **2 karty** z kolekcji kilkudziesięciu (MVP zostaje przy 1 — patrz sekcja 8 dla obecnych 12 zaimplementowanych kart, w tym skoczka zamieniającego się miejscami i odbijającego się gońca, które były tu wcześniej wymienione jako kierunek, a teraz są gotowe).

Wymagania dla systemu:

- karta ma jednoznaczną nazwę, opis i czytelny efekt na planszy;
- silnik reguł musi obsługiwać efekty jako dane/moduły, a nie przez ręczne wyjątki rozsiane w kodzie;
- w multiplayerze obie strony muszą deterministycznie widzieć i obliczać ten sam efekt;
- system powinien rozdzielać: generowanie legalnych ruchów, wykonanie ruchu, bicie, zmianę tury oraz efekty stałe;
- przed uruchomieniem meczu trzeba walidować niekompatybilne kombinacje kart.

Możliwe kategorie kart:

- modyfikacje ruchu figur;
- modyfikacje bicia/zamiany;
- reguły planszy i jej granic;
- modyfikacje tury;
- pasywne anomalie;
- jednorazowe exploity.

---

## 7. Tryby gry

### Lokalny prototyp

Gra na jednym komputerze. Działa jako główne środowisko testowania zasad. Przed rzutem monetą obaj gracze wybierają (niezależnie), którym z dwóch zapisanych loadoutów (ustawienie + karta) grają — patrz sekcja 9, `pozycja_osobista.gd`.

### Online

Pokój dla 2 osób, dołączany jednym przyciskiem "Graj online" — kto pierwszy dołączy do danego kodu pokoju, dostaje od serwera rolę hosta (białe), kolejny gracz rolę gościa (czarne); ponowne dołączenie tym samym tokenem zachowuje wcześniej przydzieloną rolę. Zawsze używany jest pierwszy zapisany loadout (bez wyboru, w przeciwieństwie do trybu lokalnego). Po zsynchronizowaniu ustawień host losuje wynik, a obie strony oglądają pełnoekranową animację rzutu monetą 3D; orzeł daje pierwszy ruch białym, reszka czarnym, z wyjątkiem startowego szacha. Implementacja używa UDP, próbuje P2P i ma awaryjny relay przez VPS. Gość widzi planszę odbitą tak, żeby jego własne figury zawsze były u dołu jego ekranu.

### Kampania / tryb fabularny

Docelowo ukryty tryb z bossami, nagrodami i odblokowaniami kart. Nie jest jeszcze zaimplementowany.

---

## 8. Stan implementacji

### Gotowe lub częściowo gotowe

- Projekt Godot 4.7 w trybie renderowania Mobile.
- Menu, intro wideo i audio oraz wymagany, zapamiętywany nick gracza. Prawy górny róg menu to logo „zryj pale ©", a pod nim pole nicku (chowane po zapisaniu); pozycje menu stoją przy lewej krawędzi. Logo zostaje na `z_index = 4`, żeby intro wideo (5) nadal je zakrywało przy starcie.
- Pozycje menu głównego to wyciągnięte w 3D napisy z `assets/NAPISY 3D/` wiszące w powietrzu przed animowanym tłem, a nie zwykłe `Button`. Kolumna stoi po lewej stronie ekranu (`SIGN_ALIGN_X`) i jest wyrównana DO LEWEJ, nie wyśrodkowana — słowa różnią się długością ponad dwukrotnie, więc wyśrodkowane dawały dwie poszarpane krawędzie i nic, o co oko mogłoby zaczepić. Wysokość kolumny (`SIGN_VIEW_FRACTION`) jest celowo mniejsza niż mieści się na ekranie, żeby zostały marginesy góra/dół, barwi się kolorem nicku (tym samym co tło), a każdy napis lewituje i **obraca się na wszystkich trzech osiach**.
- Napisy się KOŁYSZĄ, nie obracają dookoła: `YAW`/`PITCH`/`ROLL` trzymają wychylenie znacznie poniżej ćwierć obrotu (maks. ~9°), więc słowo nigdy nie staje bokiem i zawsze jest zwrócone przodem do gracza. To ograniczenie jest celowe — nie podnoś tych stałych powyżej ok. 1,2 radiana. Tempa osi są wzajemnie niewymierne, żeby ruch nie układał się w jedno powtarzalne bujanie.
- Najechanie myszą wygasza całą rotację do zera (mnożnik `1 - eased`), czyli ustawia napis równo przodem, a do tego podjeżdża on w stronę kamery i rozjaśnia się.
- Napisy noszą tę samą teksturę plastiku co pola planszy (brana z `BoardTile`, więc przeteksturowanie kafelków przeteksturuje i menu), nałożoną **triplanarnie**. Modele mają domyślne UV Blenderowego tekstu — `u` biegnie wzdłuż obrysu litery, `v` jest tylko 0 albo 1 — więc próbkowanie po nich rozmazywałoby teksturę wzdłuż konturów. Triplanar rzutuje ją przez przestrzeń obiektu i UV nie potrzebuje, dzięki czemu boki wyciągnięcia dostają to samo ziarno co lica.
- Każdy napis jest **wycelowany w kamerę** (`aim_at()`). Kolumna stoi mocno z lewej, a kamera perspektywiczna patrząca prosto przed siebie widzi wszystko poza swoją osią z boku — napis o zerowym obrocie jest równy wobec ŚWIATA, a nie wobec gracza, i wygląda jakby był odwrócony. Kołysanie odbywa się dookoła tego wycelowania, a najechanie wygasza samo kołysanie, więc napis ustawia się równo do gracza.
- Napisy przechodzą przez shader zakłócający (`shaders/napisy_zaklocenie.gdshader`) nałożony na ich kontener, nie na same napisy: siatka pikseli, rozjazd kanałów RGB, linie skanowania, ziarno i co jakiś czas rząd zsuwający się w bok. Trafienia liczone są z geometrii, więc rozsypanie obrazu nie wpływa na klikalność.
- Wygląd shadera został celowo cofnięty do tego, co pierwsza (błędna) wersja robiła przypadkiem: drobniejsza siatka, zmiękczona przez domieszkę nieskwantyzowanego obrazu (`softness`), i przyciemnienie przesunięte w niebieski (`tint`). Różnica jest taka, że teraz to są sterowalne stałe, a nie skutek uboczny dwóch błędów.
- **Dwie pułapki w tym shaderze**, obie kosztowały jasność i obie były wykryte pomiarem, nie okiem: (1) kwantyzacja UV przez `floor()` psuje pochodne, przez co GPU wybiera zgrubny poziom mipmapy — stąd wszędzie `textureLod(..., 0.0)`; (2) kończące shader `COLOR = c * COLOR` na `SubViewportContainer` mnoży przez wartość, która NIE jest biała, i zjadało kolejną jedną trzecią. Litery: 175 bez shadera, 118 z tymi błędami, 175 po poprawkach.
- **Pułapka:** główny `Control` sceny menu wypełnia ekran i ma domyślny `MOUSE_FILTER_STOP`, przez co połykał każde kliknięcie, zanim dotarło do `_unhandled_input`, gdzie liczone są trafienia. Za czasów `Button`ów było to niewidoczne, bo `Button` sam jest Controlem i łapał kliknięcie pierwszy. Dlatego `_ready()` ustawia mu `MOUSE_FILTER_IGNORE`.
- Trafienia liczone są ręcznie — prostokąt napisu jest rzutowany na ekran przez `unproject_position()`, ale **celowo bez obrotu**: obrócone słowo zajmuje mniej ekranu niż ustawione na wprost, więc prostokąt spoczynkowy zawsze zawiera to, co narysowane, i pole kliknięcia ani się nie kurczy, ani nie wędruje podczas kołysania.
- Uwaga: menu straciło nawigację klawiaturą, którą dawały `Button`y.
- Pełny ekran bez rozciągania interfejsu: `window/stretch/mode=canvas_items` + `aspect=expand` — przyciski i HUD mają natywny rozmiar, animowane tło (`tlo_ekranu_glownego.gd`) samo skaluje się do rozmiaru okna, a plansza jest kadrowana kamerą tak, by zawsze mieściła się w oknie (`_center_camera()`). Intro wideo zostaje w oryginalnym, wyśrodkowanym kwadracie 512×512 z czarnym tłem widocznym tylko podczas jego odtwarzania.
- Kreator neutralnego ustawienia figur z budżetem punktowym.
- Plansza i figury w 3D w stylu starych gier: pola to teksturowane płytki z modelu `assets/POLA/pole.glb`, a figury to billboardy `Sprite3D` zawsze zwrócone do kamery, ustawionej pod stałym kątem. Cała reszta gry pozostaje 2D — szczegóły w sekcji 9.
- Płytki lewitują: każda krąży po własnej, powolnej pętli (góra-dół, delikatny dryf na boki i lekkie kołysanie), jakby plansza unosiła się na wodzie. Amplitudy są celowo małe — przynależność figury do pola musi być czytelna na pierwszy rzut oka, a trafienia myszą dalej liczone są względem stałej siatki, a nie względem pływającej płytki.
- Kolekcja kart jako osobny, paginowany ekran (`scenes/karty.tscn`, 16 kart/strona w siatce 4×4, kafelki w proporcji 3:4, jawny przycisk „Brak karty”) zamiast panelu wewnątrz kreatora armii. Wybór jednej karty na gracza, pięć pierwszych efektów i synchronizacja kart online.
- Lokalna rozgrywka na 6×6 z możliwością poszerzania do 8×8.
- Walidacja ruchów, szach/mat/pat, promocja (dynamicznie wykrywa skrajny wiersz aktualnej planszy, działa też po rozszerzeniu do 8×8) oraz obsługa wielu króli.
- HUD liczby pozostałych pól i nicków obu stron w formacie „Białe (nick): N”.
- Animowane tło meczu, barwione dynamicznie mieszanką kolorów wygenerowanych z nicków i aktualnego materiału.
- Lobby online, synchronizacja ruchów/dodawanych pól, początkowego układu i rzutu monety.
- Własny protokół UDP z potwierdzeniami i retransmisją.
- Zamykanie pokoju po meczu: klient hosta wysyła `GAME_CLOSE`, a serwer usuwa pokój i powiadamia gościa.
- Efekty kart zaczepione przez generyczne hooki (`cards/card_hooks.gd`) zamiast sprawdzania konkretnych ID w `game_rules.gd`/`main.gd`, plus walidacja niekompatybilnych par kart przed startem meczu.
- Serwer VPS wdrożony jako usługa systemd (`zryj-chess.service`, dedykowany użytkownik `chessserver`, `Restart=always`), odporna na błędnie sformatowane pakiety (w tym historyczny przypadek `GAME_PING` bez drugiego dwukropka) — zweryfikowane testem end-to-end protokołu z zewnętrznej sieci.
- Testy jednostkowe silnika zasad w `tests/`, uruchamiane headlessowo bez otwierania edytora:
  `godot --headless --path . --script res://tests/run_tests.gd` (kod wyjścia = liczba nieudanych asercji).
- Wspólny ekran ustawień pod `Esc` (autoload `ustawienia.gd`, ta sama nakładka w menu, kreatorze armii, kolekcji kart i w trakcie meczu): wyciszenie muzyki (osobna szyna audio `Music`, nie wycisza efektów), przełącznik podświetlania legalnych ruchów, mapa klawiszy z pełnym przypisywaniem oraz wyjście z meczu. Wszystko zapamiętywane w profilu gracza.
- Wyjście z trwającego meczu: lokalnie wraca do menu, online liczy się jako poddanie — przeciwnik dostaje normalny ekran wyniku zamiast czekać na ruch, który nigdy nie przyjdzie.
- Przypisywanie klawiszy: akcje `space` (dołóż pole), `hole` (wybij dziurę) i `pause` (ustawienia) można przemapować; przypisanie na zajęty klawisz ZAMIENIA obie akcje, więc żadna nie zostaje bez klawisza. Wiązania idą po kodzie fizycznym, są zapisywane w `profile.cfg` i mają przycisk przywracania domyślnych.
- Podświetlanie legalnych ruchów (opcjonalne, domyślnie włączone): trzymana lub zaznaczona figura pokazuje pola docelowe (niebieskie) i bicia (czerwone), a mechaniki kart — gdzie wolno dołożyć pole, wybić dziurę i postawić kaczkę (bursztynowe). Liczone tym samym `GameRules.is_legal_move()`, którym walidowany jest ruch, więc nie może się rozjechać z zasadami.
- Menu główne z uporządkowaną kolumną przycisków (Lokalna gra / Gra online / Ustawianie pozycji / Ustawienia / Wyjdź z gry); zdjęcie „robcza” jest już tylko dekoracją, a nie ukrytym przyciskiem startu meczu.
- Jeden przycisk dołączania online zamiast osobnych "host"/"dołącz" — rolę przydziela serwer wg kolejności dołączenia do kodu pokoju.
- Widok planszy online zawsze pokazuje własną połowę gracza u dołu ekranu — gość ma obróconą o 180° kamerę, więc figury i pola stoją w prawdziwych, logicznych współrzędnych po obu stronach (bez lustrzanego przeliczania jak dawne `_view()`).
- Wybór figury przy promocji pionka (hetman/wieża/goniec/skoczek) zamiast automatycznej promocji do hetmana.
- Dwa zapisywalne loadouty (ustawienie figur + karta) na gracza, przełączane w kreatorze armii; w lokalnym versus biały i czarny niezależnie wybierają, którym loadoutem grają, tuż przed rzutem monetą.
- Placeholder ekranu wyniku (`scenes/wynik.tscn`) zamiast powrotu od razu do menu: „<nick> wygrywa” zawsze, a online dodatkowo duży napis „W FAPS”/„L FAPS” z perspektywy każdego z graczy osobno (lokalnie bez tego, bo obaj grający patrzą w ten sam ekran). Remis pokazuje „Remis”.
- Szachownica wyśrodkowana na ekranie podczas meczu (`BoardRoot`, przeliczane też przy zmianie rozmiaru okna) — wcześniej po zmianie trybu skalowania zostawała przy lewej krawędzi.
- 12 kart w `card_registry.gd`/`card_hooks.gd` (pierwotnych 5 + 7 nowych): `knight_swap` (zamiana miejsc zamiast bicia, taki skoczek nie daje szacha), `bouncing_bishop` (odbija się od krawędzi i niezniszczalnych figur), `castling` (bez śledzenia ruchów i bez limitu — działa dla każdej pary król+wieża w linii), `double_step_pawns` (piony zawsze mogą o dwa pola), `omni_pawns` (piony ruszają się we wszystkie 4 strony, biją tylko po skosie do przodu), `board_hole` (klawisz `X`, jedna trwała dziura dla właściciela karty, odwrotność dokładania pola), `board_10x10` (podnosi limit planszy z 8×8 do 10×10).

Kolekcja kart nadal mieści się na jednej stronie (12 ≤ 16/stronę), więc paginacja w `karty.gd` nie wymagała żadnej zmiany.

### Niezaimplementowane

- Kampania, fabuła, bossowie, progresja i odblokowania.
- Doprecyzowany balans armii, kart oraz planszy.
- Pełny mecz online między dwoma fizycznie różnymi sieciami, powtarzalny kilka razy z rzędu (wymaga dwóch osób/urządzeń — zaplanowane, jeszcze nieprzeprowadzone).
- CI uruchamiający testy automatycznie przy każdym commicie.

---

## 9. Architektura techniczna

### Technologia

- Silnik: Godot 4.7.
- Język: GDScript.
- Renderowanie: Mobile.
- Plansza i figury: 3D w osobnym `SubViewport` (własny `World3D`) — pola to `BoardTile` (model `pole.glb` + jedna z dwóch tekstur), figury to billboardy `Sprite3D` (`BILLBOARD_FIXED_Y`), kamera pod stałym kątem. Reszta scen (HUD, tło, okna) pozostaje w 2D i rysuje się nad kontenerem planszy.
- `SubViewport` planszy jest wymiarowany w PRAWDZIWYCH pikselach okna, a jego kontener jest z powrotem skalowany w dół (`BoardTile.fit_to_pixels()`). Bez tego plansza renderowała się w rozdzielczości bazowego układu 2D (np. 910×276) i była rozciągana ponad 4× na ekran — tekst i przyciski są przerysowywane w natywnej rozdzielczości, ale `SubViewport` to tekstura i po prostu się powiększa. Konsekwencja: pozycję myszy trzeba jeszcze podzielić przez `board_container.scale`, żeby wrócić do pikseli viewportu przed `project_ray_*`.
- Górna ścianka płytki leży dokładnie na `y = 0`, czyli tam, gdzie dawniej był płaski `PlaneMesh`. Dzięki temu cała reszta matematyki planszy (rzucanie promienia na płaszczyznę `y = 0`, figury na `PIECE_Y`, podpowiedzi na `HINT_Y`) działa bez zmian mimo grubości modelu.
- Ten `SubViewport` jest przezroczysty (widać przez niego animowane tło 2D), więc nie ma w nim `WorldEnvironment` — rolę światła otoczenia gra `emission` materiału. Wszystko inne w tym viewporcie jest `unshaded`, więc światła dotyczą wyłącznie płytek.
- Tło menu i meczu jest 3D: każda z trzech warstw grafiki leży na **wycinku innej sfery** i dryfuje, obracając się wokół środka swojej kuli. Dzięki temu grafika wybrzusza się ku środkowi ekranu i ucieka na brzegach.
- Kamera stoi **na zewnątrz** tych sfer i to jest istotne: ze środka kuli nie widać żadnej krzywizny, bo każdy punkt powierzchni jest tak samo daleko i rzutuje się idealnie płasko. Wybrzuszenie bierze się wyłącznie stąd, że biegun jest bliżej kamery niż obrzeże.
- Warstwy to **czapy**, nie pełne kule. Pełną kulę trzeba teksturować albo równopromieniście (szew na jednym południku i szczypanie na biegunach), albo triplanarnie (trzy rzuty stykające się twardymi prostokątnymi krawędziami) — oba były sprawdzone i oba były wyraźnie widoczne na grafice zbudowanej z dużych, miękkich plam. Czapa przyjmuje płaskie UV, więc grafika ląduje na niej dokładnie tak, jak narysowana.
- Środkowa warstwa oddycha: rozjaśnia się i przygasa **cosinusem**, nie piłą. Wcześniej była to pięćdziesięciosekundowa rampa zerowana skokiem — stąd nagły przeskok tła do stanu początkowego przy każdym obiegu. Rampa szła też do 100, co mnożyło każdy kanał tak daleko poza biel, że kolor znikał na długo przed szczytem; `PULSE_MAX` (40) to świadome prześwietlenie — powyżej ok. 1,9 typowa barwa nicku ma wszystkie kanały ponad 1 i szczyt oddechu jest biały. Cosinus odpowiada za płynność wzrostu i opadania, a nie za ograniczenie jasności. `PULSE_MIN` decyduje o tym, jak ciemne wydaje się tło, bo tam oddech spędza połowę czasu — podnoszenie `PULSE_MAX` nic na to nie daje.
- **Zakresy głębi, jakie zajmują powierzchnie czap, nie mogą na siebie zachodzić.** Nic tu nie zapisuje głębi — kolejność trzyma sam `render_priority` — więc tam, gdzie dwie czapy się przenikają, bliższa i tak rysuje się pod dalszą i jedna widocznie przebija przez drugą przy krawędziach kadru. Tylna czapa siedzi na 20, a nie na 16, właśnie dlatego: przy 16 jej powierzchnia zaczynała się (16,00), zanim skończyła się środkowa (17,63).
- Każda kula stoi w **innym miejscu** (`apex` — gdzie jej biegun wypada na ekranie, w zakresie -1..1), więc trzy wybrzuszenia mają szczyty w trzech różnych punktach zamiast nakładać się na osi kamery. To właśnie sprawia, że warstwy czytają się jako trzy osobne kule, a nie jedna powierzchnia.
- `half_angle` czapy musi zostać wyraźnie większy niż to, co kamera z niej widzi (ok. 15–22° zależnie od warstwy), inaczej przy dryfie krawędź płata wjeżdża w kadr. Podniesienie `sway` albo `apex` wymaga podniesienia `half_angle` razem z nimi — a przy dużym `apex` sama kula może przestać sięgać rogu kadru, czego `half_angle` już nie naprawi (trzeba wtedy większego `radius`).
- Światła planszy (wszystkie dodawane z kodu w `BoardTile`): dwa `DirectionalLight3D` dające płytkom kształt (bez nich faza i boki byłyby tak samo jasne jak góra) oraz `OmniLight3D` zawieszona nad środkiem planszy — to ona sprawia, że jedna płytka jest jaśniejsza od drugiej zamiast równego zalania całej planszy. Lampa ma `omni_attenuation = 0`, czyli bez fizycznego spadku 1/d², żeby zasięg dało się wycelować ręcznie, a jej wysokość i zasięg skalują się z rozmiarem planszy (`focus_lighting()`), więc działa tak samo dla 8×8 i 10×10. Płytka wznosząca się na lewitacji zbliża się do lampy i łapie odrobinę więcej światła.
- Sieć gry: `PacketPeerUDP` i własny protokół wiadomości.
- Serwer pomocniczy: Python, UDP.

### Główne komponenty

| Komponent | Odpowiedzialność |
| --- | --- |
| `main.gd` | Stan meczu, ruchy, walidacja, tury, szach/mat/pat, rozszerzanie planszy, akcje sieciowe, wybór figury przy promocji, lustrzany widok planszy online (obrót kamery o 180°) i dynamiczna barwa tła zależna od materiału. W trybie lokalnym pokazuje ekran wyboru loadoutu przed rzutem monetą. |
| `game_rules.gd` | Czysty silnik zasad: generowanie ruchów, ataki, szach, wielokrólewskość, mata/pat, dynamiczna promocja i losowanie bezpiecznej pozycji startowej. Pyta `CardHooks` ogólnie o efekty kart, nie zna konkretnych ID. |
| `cards/card_registry.gd` | Dane kart: id, nazwa, opis, deklarowane hooki oraz walidacja niekompatybilnych par (`is_compatible`). |
| `cards/card_hooks.gd` | Jedyne miejsce mapujące hooki (moves/capture/attacks/blocked_squares/win_condition/after_move/stalemate) na konkretne ID kart; `game_rules.gd` i `main.gd` wołają je generycznie. |
| `ustawianie.gd` | Kreator armii, budżet punktów, drag-and-drop; przełącznik dwóch loadoutów i przycisk otwierający kolekcję kart. |
| `karty.gd` | Paginowany ekran kolekcji kart (16/stronę, siatka 4×4, kafelki 3:4) z jawną opcją braku karty. |
| `network_manager.gd` | Pokoje online, P2P hole punching, relay, niezawodne przesyłanie akcji, synchronizacja nicków, walidacja kompatybilności kart oraz przydzielanie roli host/gość wg kolejności dołączenia (serwer decyduje, nie klient). |
| `lobby.gd` | Interfejs dołączania do pokoju jednym przyciskiem; zawsze wysyła pierwszy zapisany loadout. |
| `pozycja_osobista.gd` | Autoload przechowujący dwa loadouty (układ + karta), profil nicku, ustawienia (wyciszenie muzyki, podświetlanie ruchów, przypisania klawiszy) i deterministyczny kolor gracza — wszystko trwale zapisywane w `profile.cfg`. |
| `ustawienia.gd` | Autoload z nakładką ustawień/pauzy nad każdą sceną: dźwięk, podświetlanie ruchów, mapa klawiszy, wyjście z meczu. Nie pauzuje drzewa (`NetworkManager` musi dalej działać) — sceny pollujące mysz pytają `Ustawienia.is_open()`. |
| `figura.gd` | Prezentacja figury jako billboardu `Sprite3D`, typ, kolor i promocja (bez własnego hitboxa — trafienia liczy `stoi_figura()` po polu pod myszą). |
| `board_tile.gd` | Klasa `BoardTile`: jedno pole planszy z modelu `pole.glb` (materiały, normalizacja rozmiaru modelu, oświetlenie planszy) wraz z animacją lewitacji. Wspólna dla meczu i kreatora armii. |
| `menu_sign_3d.gd` | Klasa `MenuSign3D`: jedna pozycja menu jako wiszący napis 3D — wczytanie modelu, wyśrodkowanie na własnym bounding boksie, materiał, kołysanie, stan najechania i rzutowany na ekran prostokąt trafień. Gdy model jest pusty lub go brak, buduje zastępczy `TextMesh`. |
| `viewport_3d.gd` | Klasa `Viewport3D`: wspólna obsługa treści 3D wstawianej w sceny 2D — antyaliasing oraz `fit_to_pixels()` wymiarujące `SubViewport` w prawdziwych pikselach zamiast w jednostkach układu 2D. Używane przez obie plansze i menu. |
| `hud.gd` | Liczniki dodatkowych pól i dziur (dziury tylko dla strony z kartą `board_hole`), nazwy stron oraz wyraźny wskaźnik tury w barwie nicku gracza. |
| `rzut_moneta.gd`, `control.gd` | Zsynchronizowana, pełnoekranowa prezentacja rzutu monety 3D oraz przywracanie globalnych ustawień czasu/fizyki. |
| `tlo_ekranu_glownego.gd` | Animowane tło menu/meczu: trzy warstwy grafiki na wycinkach trzech różnych sfer, dryfujące niezależnie; przyjmuje barwę od `main.gd`/`menu_glowne.gd`. |
| `wynik.gd` | Placeholder ekranu wyniku po meczu; czyta dane z tymczasowych, nietrwałych pól w `PozycjaOsobista`. |
| `tests/*.gd` | Headlessowy zestaw testów jednostkowych silnika zasad (`tests/run_tests.gd` jako punkt wejścia). |

Autoloady zdefiniowane w `project.godot`:

- `PozycjaOsobista`
- `NetworkManager`

---

## 10. Struktura plików

```text
zryj-chess-main/
├── project.godot                 # Konfiguracja Godot i autoloady
├── PROJECT_KNOWLEDGE.md          # Ten dokument
├── scenes/                       # Sceny Godot: menu, gra, lobby, HUD, figury, kolekcja kart itd.
├── scripts/                      # Logika GDScript
├── cards/                        # Dane kart (card_registry.gd) i generyczne hooki (card_hooks.gd)
├── tests/                        # Headlessowy zestaw testów jednostkowych silnika zasad
├── assets/                       # Tekstury, modele, intro i grafiki menu
├── audio/                        # Muzyka i efekty dźwiękowe
└── docs/compose/plans/           # Historyczne plany implementacji
```

Poza katalogiem gry, w `C:\Users\Mariusz\Desktop\vibe code\files\` znajdują się:

- `server.py` — serwer rendezvous/relay dla protokołu `GAME_*`;
- `client.py` — starszy, niezależny klient czatu terminalowego (nie jest klientem Godot).

---

## 11. Sieć i wdrożenie

Przepływ online:

```text
Oboje klientów wysyła GAME_JOIN:kod:token (bez roli)
        → serwer odsyła GAME_ROLE:token:host|guest (pierwszy = host, kolejny = guest)
        → serwer przekazuje im adresy UDP (GAME_PEER)
        → klienci próbują bezpośredniego P2P
        → gdy P2P nie działa, używają relaya VPS
```

Aktualne ustawienia w `scripts/network_manager.gd`:

- port VPS: `51820`;
- adres VPS: `31.70.109.158`;
- timeout P2P: 4 sekundy;
- heartbeat: 10 sekund.

Stan wdrożenia:

1. ✅ `server.py` działa na VPS jako usługa systemd (`zryj-chess.service`, użytkownik `chessserver`, `Restart=always`), niezależna od otwartego terminala.
2. ✅ Port UDP `51820` jest otwarty i potwierdzony jako osiągalny z zewnątrz (test protokołu end-to-end spoza VPS).
3. ✅ `VPS_HOST`/`VPS_PORT` w `network_manager.gd` wskazują na aktualny adres/port.
4. ✅ Serwer ma obsługę błędów wokół każdego pakietu — pojedynczy błędnie sformatowany pakiet (np. `GAME_PING` bez drugiego dwukropka) nie ubija już procesu.
5. ❌ **Wciąż do zrobienia:** pełny mecz między dwoma fizycznie różnymi sieciami (np. dwa różne Wi-Fi albo Wi-Fi + LTE), powtarzalny kilka razy z rzędu bez pomocy dewelopera.

---

## 12. Znane ograniczenia i ryzyka

### Logika gry

- Kreator wymaga króla, ale nie wymusza dokładnie jednego króla ani kompletnej, sensownej armii.
- Potrzebne są reguły dla nietypowych sytuacji po dołożeniu pola lub z kartami zmieniającymi granice planszy.

### Sieć i bezpieczeństwo

- UDP jest nieszyfrowane i nie ma pełnego uwierzytelniania; obecnie nie jest to system do publicznego, wrogiego środowiska.
- VPS działa pod jednym, prowizorycznym adresem — brak DNS/domeny, brak automatycznego odzyskiwania po awarii samej maszyny (tylko procesu, przez systemd).

### Proces

- Nazewnictwo i kod zawierają pozostałości eksperymentów; przy rozwijaniu systemu kart warto oddzielić silnik zasad od interfejsu i efektów wizualnych.
- Testy jednostkowe pokrywają silnik zasad (`tests/`), ale nie ma jeszcze testów UI/integracyjnych ani CI uruchamiającego je automatycznie przy każdym commicie.

---

## 13. Najbliższe priorytety

1. **Test multiplayera na różnych sieciach:** VPS jest wdrożony i zweryfikowany technicznie (usługa systemd, odporność na złe pakiety, protokół end-to-end) — brakuje jeszcze powtarzalnego, pełnego meczu między dwoma fizycznie różnymi sieciami.
2. **Weryfikacja gotowości MVP:** pełny mecz online, od ustawienia armii po mata, bez pomocy dewelopera i bez restartu z powodu błędu sieci, powtarzalny kilka razy z rzędu.
3. **Rozbudowa kolekcji kart:** kolejne karty dodaje się przez `card_registry.gd`/`card_hooks.gd`; ekran kolekcji (`karty.gd`) już wspiera paginację po 16 kart, więc UI skaluje się bez dodatkowych zmian.
4. **Doprecyzowanie balansu:** armia, karty i rozmiar planszy.
5. **Specyfikacja kampanii:** pierwsza lokacja, jeden boss, jedna nagroda-karta i zapis progresu.

---

## 14. Otwarte decyzje

Poniższe pytania wymagają decyzji zespołu przed większą implementacją:

- Czy karty są wyłącznie pasywne, czy część aktywuje się ręcznie podczas tury?
- Czy obie karty są jawne od początku meczu, czy niektóre są ukryte?
- Jak multiplayer zachowuje uczciwość: pełna kolekcja dla wszystkich, formaty draftu, ograniczony ranking, czy inny model?
- Czy przygotowanie armii ma mieć dodatkowe ograniczenia poza budżetem 16 punktów?
- Czy dołożenie pola jest zasobem na całą grę, na turę, czy może być modyfikowane kartami?
- Jak daleko wolno odejść od klasycznych szachów, aby gra nadal była intuicyjna?
- Czy kampania ma być całkowicie ukryta, czy odkrywana przez sekretne warunki w menu/meczach?
- Jaki jest docelowy tytuł: „Mini Chess”, „Zryj Chess”, czy inna nazwa (zależna od jeszcze nieustalonego klimatu gry)?
