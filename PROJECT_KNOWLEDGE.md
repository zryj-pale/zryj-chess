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
- Pion promuje się automatycznie do hetmana.
- Nie ma jeszcze roszady, bicia w przelocie, ruchu pionem o dwa pola ani mechaniki pasowania.

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

Przed rozgrywką każdy gracz wybiera **2 karty** z kolekcji kilkudziesięciu. Karty modyfikują reguły gry, figury lub planszę.

Potwierdzone przykłady kierunku:

- skoczek zamiast zbijać figurę zamienia się z nią miejscami;
- gońce mogą odbijać się od ścian planszy.

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

Gra na jednym komputerze. Działa jako główne środowisko testowania zasad.

### Online

Pokój dla 2 osób. Host gra białymi, dołączający czarnymi. Po zsynchronizowaniu ustawień host losuje wynik, a obie strony oglądają pełnoekranową animację rzutu monetą 3D; orzeł daje pierwszy ruch białym, reszka czarnym, z wyjątkiem startowego szacha. Implementacja używa UDP, próbuje P2P i ma awaryjny relay przez VPS.

### Kampania / tryb fabularny

Docelowo ukryty tryb z bossami, nagrodami i odblokowaniami kart. Nie jest jeszcze zaimplementowany.

---

## 8. Stan implementacji

### Gotowe lub częściowo gotowe

- Projekt Godot 4.7 w trybie renderowania Mobile.
- Menu, intro wideo i audio oraz wymagany, zapamiętywany nick gracza.
- Kreator neutralnego ustawienia figur z budżetem punktowym.
- Wybór jednej karty na gracza, pięć pierwszych efektów i synchronizacja kart online.
- Lokalna rozgrywka na 6×6 z możliwością poszerzania do 8×8.
- Walidacja ruchów, szach/mat/pat, promocja oraz obsługa wielu króli.
- HUD liczby pozostałych pól i nicków obu stron.
- Animowane tło meczu, barwione dynamicznie mieszanką kolorów wygenerowanych z nicków i aktualnego materiału.
- Lobby online, synchronizacja ruchów/dodawanych pól, początkowego układu i rzutu monety.
- Własny protokół UDP z potwierdzeniami i retransmisją.
- Zamykanie pokoju po meczu: klient hosta wysyła `GAME_CLOSE`, a serwer usuwa pokój i powiadamia gościa.

### Niezaimplementowane

- Kampania, fabuła, bossowie, progresja i odblokowania.
- Doprecyzowany balans armii, kart oraz planszy.
- Produkcyjny hosting i konfiguracja sieci.
- Testy automatyczne i pełna walidacja jakości.

### Ważny stan Git

Repozytorium zawiera znaczące lokalne, niezatwierdzone zmiany w aktualnej wersji multiplayera i gry. Przed większą pracą należy je przejrzeć, przetestować i zapisać w logicznych commitach. Dokumenty w `docs/compose/plans/` są historycznymi planami i ich checklisty nie odzwierciedlają aktualnego stanu kodu.

---

## 9. Architektura techniczna

### Technologia

- Silnik: Godot 4.7.
- Język: GDScript.
- Renderowanie: Mobile.
- Logika planszy: `TileMapLayer`.
- Sieć gry: `PacketPeerUDP` i własny protokół wiadomości.
- Serwer pomocniczy: Python, UDP.

### Główne komponenty

| Komponent | Odpowiedzialność |
| --- | --- |
| `main.gd` | Stan meczu, ruchy, walidacja, tury, szach/mat/pat, rozszerzanie planszy, akcje sieciowe i dynamiczna barwa tła zależna od materiału. |
| `game_rules.gd` | Czysty silnik zasad: generowanie ruchów, ataki, szach, wielokrólewskość, mata/pat i losowanie bezpiecznej pozycji startowej. |
| `ustawianie.gd` | Kreator armii, budżet punktów, drag-and-drop, zapis neutralnego układu. |
| `network_manager.gd` | Pokoje online, P2P hole punching, relay, niezawodne przesyłanie akcji oraz synchronizacja nicków. |
| `lobby.gd` | Interfejs tworzenia i dołączania do pokoju. |
| `pozycja_osobista.gd` | Autoload przechowujący układ, kartę, profil nicku i deterministyczny kolor gracza. |
| `figura.gd` | Prezentacja figury, hitbox, typ, kolor i promocja. |
| `hud.gd` | Liczniki dodatkowych pól i wizualizacja aktualnej tury. |
| `rzut_moneta.gd`, `control.gd` | Zsynchronizowana, pełnoekranowa prezentacja rzutu monety 3D oraz przywracanie globalnych ustawień czasu/fizyki. |

Autoloady zdefiniowane w `project.godot`:

- `PozycjaOsobista`
- `NetworkManager`

---

## 10. Struktura plików

```text
zryj-chess-main/
├── project.godot                 # Konfiguracja Godot i autoloady
├── PROJECT_KNOWLEDGE.md          # Ten dokument
├── scenes/                       # Sceny Godot: menu, gra, lobby, HUD, figury itd.
├── scripts/                      # Logika GDScript
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
Host i gość rejestrują kod pokoju na VPS
        → serwer przekazuje im adresy UDP
        → klienci próbują bezpośredniego P2P
        → gdy P2P nie działa, używają relaya VPS
```

Aktualne ustawienia w `scripts/network_manager.gd`:

- port VPS: `51820`;
- adres VPS: `31.70.109.158` (tymczasowy — działa tylko lokalnie);
- timeout P2P: 4 sekundy;
- heartbeat: 10 sekund.

Aby udostępnić online prawdziwym graczom:

1. uruchomić `server.py` na VPS;
2. otworzyć UDP port `51820` w firewallu/VPS;
3. wpisać publiczne IP lub domenę VPS w `VPS_HOST`;
4. przetestować grę na dwóch różnych łączach internetowych;
5. przygotować obsługę błędów, logi i instrukcję wdrożenia.

---

## 12. Znane ograniczenia i ryzyka

### Logika gry

- Promocja pionka używa wierszy `1` i `6`, co może wymagać zmiany po rozszerzeniu planszy do pełnego 8×8.
- Kreator wymaga króla, ale nie wymusza dokładnie jednego króla ani kompletnej, sensownej armii.
- Potrzebne są reguły dla nietypowych sytuacji po dołożeniu pola lub z kartami zmieniającymi granice planszy.

### Sieć i bezpieczeństwo

- `VPS_HOST` jest lokalny i wymaga konfiguracji przed testami zdalnymi.
- UDP jest nieszyfrowane i nie ma pełnego uwierzytelniania; obecnie nie jest to system do publicznego, wrogiego środowiska.
- Serwer Python wymaga odporniejszego obsłużenia błędnie sformatowanych pakietów, szczególnie `GAME_PING`.

### Proces

- Należy chronić niezatwierdzone zmiany Git i nie nadpisywać ich bez świadomego przeglądu.
- Brakuje testów automatycznych oraz stałego procesu sprawdzania scen w Godot.
- Nazewnictwo i kod zawierają pozostałości eksperymentów; przy rozwijaniu systemu kart warto oddzielić silnik zasad od interfejsu i efektów wizualnych.

---

## 13. Najbliższe priorytety

1. **Stabilizacja prototypu:** uruchomić grę, sprawdzić wszystkie sceny i rozegrać lokalny mecz od ustawienia po mata.
2. **Test multiplayera:** skonfigurować VPS i przeprowadzić test na dwóch różnych sieciach.
3. **Zabezpieczenie stanu:** przejrzeć oraz podzielić obecne zmiany na sensowne commity.
4. **Projekt systemu kart:** stworzyć model danych karty oraz punkty rozszerzeń w silniku zasad.
5. **Pierwszy pionowy wycinek docelowej gry:** jedna karta dla figury, jedna karta planszy, jasne UI aktywnych efektów i pełna synchronizacja online.
6. **Specyfikacja kampanii:** pierwsza lokacja, jeden boss, jedna nagroda-karta i zapis progresu.

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
