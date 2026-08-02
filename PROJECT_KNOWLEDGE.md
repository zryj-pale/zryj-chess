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

> Szachy zainfekowane złośliwym oprogramowaniem: gracze budują własne, nieuczciwe kombinacje zasad i próbują przetrwać ich konsekwencje.

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

### Motyw świata

Oficjalne, klasyczne szachy zostały zmodyfikowane lub zainfekowane przez złośliwe oprogramowanie. Reguły, figury i interfejs zaczynają zachowywać się niezgodnie z regulaminem.

Karty mogą być przedstawiane jako:

- exploity;
- błędy reguł;
- uszkodzone moduły;
- nieautoryzowane patche;
- fragmenty wirusa lub odzyskane dane.

Bossowie kampanii powinni być uszkodzonymi komponentami systemu, anomaliami albo administratorami/antywirusem próbującymi przejąć kontrolę nad zainfekowaną grą.

### Kierunek graficzny

Styl ma wyglądać jak celowo chaotyczny zbiór tekstur, zachowujący jeden psychodeliczny klimat. Nie jest to realizm ani klasyczne fantasy.

Stałe elementy wizualne:

- klasyczna siatka szachownicy jako czytelna baza;
- rozpoznawalne figury i wyraźna informacja o turze;
- glitch, artefakty kompresji, nietypowe kolory, błędne fonty i zakłócenia jako warstwa „infekcji”;
- efekty dopasowane do mechaniki karty (np. odbijający się goniec zostawia ślad odbicia).

**Granica:** grafika może być dziwna, ale nigdy nie może ukrywać pola, legalnego ruchu, stanu figury ani tury.

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
- Jest bicie, wykrywanie szacha, mata i pata.
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

Pokój dla 2 osób. Host gra białymi, dołączający czarnymi. Obecna implementacja używa UDP, próbuje P2P i ma awaryjny relay przez VPS.

### Kampania / tryb fabularny

Docelowo ukryty tryb z bossami, nagrodami i odblokowaniami kart. Nie jest jeszcze zaimplementowany.

---

## 8. Stan implementacji

### Gotowe lub częściowo gotowe

- Projekt Godot 4.7 w trybie renderowania Mobile.
- Menu, intro wideo i audio.
- Kreator neutralnego ustawienia figur z budżetem punktowym.
- Lokalna rozgrywka na 6×6 z możliwością poszerzania do 8×8.
- Podstawowa walidacja ruchów, szach/mat/pat i promocja.
- HUD liczby pozostałych pól.
- Lobby online i synchronizacja ruchów/dodawanych pól.
- Własny protokół UDP z potwierdzeniami i retransmisją.

### Niezaimplementowane

- System kart.
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
| `main.gd` | Stan meczu, ruchy, walidacja, tury, szach/mat/pat, rozszerzanie planszy, akcje sieciowe. |
| `ustawianie.gd` | Kreator armii, budżet punktów, drag-and-drop, zapis neutralnego układu. |
| `network_manager.gd` | Pokoje online, P2P hole punching, relay, niezawodne przesyłanie akcji. |
| `lobby.gd` | Interfejs tworzenia i dołączania do pokoju. |
| `pozycja_osobista.gd` | Autoload przechowujący układ przygotowany przez gracza. |
| `figura.gd` | Prezentacja figury, hitbox, typ, kolor i promocja. |
| `hud.gd` | Liczniki dodatkowych pól i wizualizacja aktualnej tury. |

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
- Jaki jest docelowy tytuł: „Mini Chess”, „Zryj Chess”, czy nazwa związana z infekcją/systemem?

