# Sokoban AI

Projekt gry Sokoban 2D w Godot Engine 4.7.2 (GDScript). Kampania liczy 12 poziomów o rosnącej trudności, odblokowywanych po kolei. Można grać ręcznie albo uruchomić z HUD solver A*, który wybiera plan o najmniejszej liczbie ruchów lub najniższym koszcie energii. Gra i solver korzystają z tego samego modelu fizycznego: przyczepności kół robota, tarcia, poślizgu, toczenia beczek, płyt naciskowych z drzwiami i jednokierunkowych uskoków. W grze i w trybie bez okna dostępne są trzy heurystyki.

## Uruchomienie

1. Otwórz katalog repozytorium jako projekt w Godot 4.7.2 (`project.godot`).
2. Uruchom projekt klawiszem `F5`. Sceną główną jest `main.tscn`.

Do samej gry nie są potrzebne zewnętrzne grafiki: plansza, gracz i skrzynie są rysowane programowo.

## Sterowanie i interfejs

| Klawisz lub element HUD | Działanie |
| --- | --- |
| `WASD` lub strzałki | Ruch gracza i pchanie skrzyni |
| `R` lub **Resetuj poziom** | Ponowne wczytanie bieżącego poziomu |
| `N` lub **Następny poziom** | Przejście do kolejnego poziomu po ukończeniu bieżącego |
| **Poziom** | Wybór jednego z odblokowanych poziomów kampanii |
| **Najmniej ruchów** / **Najmniej energii** | Wybór kosztu planowania A*: `STEPS` / `ENERGY` |
| **Heurystyka** | Wybór h1 Manhattan, h2 masa i tarcie lub h3 Terrain-Aware |
| **Rozwiąż AI** | Wyznaczenie planu od aktualnego stanu planszy i rozpoczęcie odtwarzania |
| **Zatrzymaj AI** | Zatrzymanie kolejnych akcji planu; trwająca animacja kończy się bez przerywania |

HUD pokazuje liczbę wykonanych ruchów, zużytą energię, maksymalną siłę robota i komunikat o ostatnim działaniu. Po wczytaniu poziomu komunikat zawiera jego krótki opis, a po pchnięciu — siłę robota i siłę potrzebną do ruszenia ciała. Ruch gracza i skrzyni jest animowany; poślizg skrzyni, toczenie beczki i poślizg robota przebiegają przez kolejne pola wyznaczone przez model fizyczny. Legenda pod planszą pokazuje tylko elementy występujące na danym poziomie. Podczas animacji i po ukończeniu poziomu kolejne ruchy są blokowane.

Sekcja AI pokazuje status i statystyki ostatniego wyszukiwania: tryb kosztu, czas w ms, liczbę rozwiniętych i odkrytych stanów, długość planu oraz jego energię. Po znalezieniu rozwiązania każda akcja planu przechodzi przez tę samą funkcję ruchu i model fizyczny co ruch ręczny; następna akcja rozpoczyna się dopiero po zakończeniu animacji. Nieudany ruch AI przerywa odtwarzanie i wyświetla jego powód. Podczas odtwarzania `WASD` i strzałki są ignorowane, ale `R` nadal resetuje poziom. Reset i zmiana poziomu usuwają plan oraz statystyki AI; zatrzymanie odtwarzania zachowuje statystyki ostatniego wyszukiwania.

Wyszukiwanie jest synchroniczne: napis „Planowanie...” może pojawić się przed wywołaniem solvera, lecz okno gry nie reaguje podczas samego obliczania planu. Gra przekazuje limit 100 000 rozwiniętych stanów i 30 000 ms. Osiągnięcie limitu czasu lub stanów oznacza, że nie ustalono rozwiązywalności planszy, a nie że rozwiązanie nie istnieje.

Po zajęciu skrzyniami wszystkich celów pojawia się ekran ukończenia z liczbą ruchów i energią, informacją o odblokowanym poziomie i rekordzie. Można przejść do następnego poziomu, zagrać ponownie albo zamknąć komunikat. Zamknięcie komunikatu nie odblokowuje ruchu na ukończonym poziomie; można go zresetować lub wybrać inny.

## Poziomy

### Kampania

Kolejność poziomów zapisano w `levels/campaign.json`, a same plansze w `levels/campaign/`. Na początku dostępny jest tylko poziom 1; ukończenie poziomu odblokowuje następny. Zablokowane poziomy są widoczne w selektorze, ale nie można ich wybrać. Rozwiązanie wykonane przez AI także odblokowuje kolejny poziom (stała `AI_COMPLETION_UNLOCKS` w `scripts/game.gd`).

Postęp i najlepsze wyniki (najmniej ruchów, przy remisie mniej energii) zapisuje `scripts/campaign.gd` w `user://progress.cfg`; w systemie Windows jest to `%APPDATA%\Godot\app_userdata\Sokoban\progress.cfg`. Aby zacząć od nowa, usuń ten plik.

| Nr | Nazwa | Nowy element | Optymalne rozwiązanie (ruchy / pchnięcia) |
| ---: | --- | --- | ---: |
| 1 | Pierwsze kroki | pchanie | 7 / 4 |
| 2 | Porządki w magazynie | dwie skrzynie, narożniki | 22 / 6 |
| 3 | Lodowisko | poślizg skrzyni po lodzie | 26 / 10 |
| 4 | Poślizg robota | robot ślizga się i traci przyczepność | 12 / 6 |
| 5 | Ruchome piaski | piasek łapie skrzynie, słabszy chwyt | 22 / 7 |
| 6 | Ciężarowiec | skrzynie 60 i 75 kg | 34 / 17 |
| 7 | Beczki | beczki toczą się do przeszkody | 16 / 4 |
| 8 | Uskoki | pola jednokierunkowe | 31 / 16 |
| 9 | Płyta naciskowa | płyta (≥ 40 kg) otwiera drzwi | 25 / 12 |
| 10 | Lodowe beczki | beczki + lód + piasek | 31 / 7 |
| 11 | Śluza | płyta, drzwi i uskok jednocześnie | 43 / 16 |
| 12 | Wielki magazyn | wszystkie mechaniki | 52 / 16 |

Poziomy wprowadzające nową mechanikę (4, 7) są celowo krótsze od poprzednich. Rozwiązywalność każdego poziomu potwierdza solver (`tests/check_levels.gd`, opis w sekcji [Testy](#testy)); AI w grze rozwiązuje wszystkie przy domyślnych limitach w obu trybach kosztu.

### Pliki poziomów

| Plik | Zawartość | Przeznaczenie |
| --- | --- | --- |
| `levels/campaign/*.json` | 12 poziomów kampanii | Rozgrywka |
| `levels/demo_level.json` | Dwie skrzynie (35 i 45 kg), dwa cele, lód i piasek | Plansza testowa solvera i przykłady CLI |
| `levels/win_test.json` | Jedna skrzynia (35 kg) i jeden cel | Test ekranu ukończenia |

Poziomy są wczytywane z JSON przez `scripts/level_data.gd`. Pola:

- `map` — tablica wierszy (znaki w tabeli poniżej),
- `name`, `description` — nazwa w selektorze i opis wyświetlany po wczytaniu,
- `robot_force` — maksymalna siła silnika robota w N (domyślnie 300),
- `plate_mass` — nacisk w kg wymagany na każdej płycie, by otworzyć drzwi (domyślnie 40),
- `boxes` — masy ciał według indeksu w kolejności odczytu mapy (wiersz po wierszu; skrzynie i beczki numerowane wspólnie). Domyślnie skrzynia ma 35 kg, beczka 30 kg.

| Znak mapy | Znaczenie |
| --- | --- |
| `#` | Ściana |
| `.` | Zwykłe podłoże (drewno) |
| `G` | Cel |
| `P` | Pozycja startowa robota |
| `B` | Skrzynia |
| `*` | Skrzynia na celu |
| `O` | Beczka |
| `I` | Lód |
| `S` | Piasek |
| `_` | Płyta naciskowa |
| `D` | Drzwi (otwarte, gdy wszystkie płyty są obciążone) |
| `>` `<` `^` `v` | Uskok: można na niego wjechać tylko zgodnie ze strzałką |

Skrzyń może być więcej niż celów (np. skrzynia, która tylko obciąża płytę). Poziom jest ukończony, gdy na każdym celu stoi skrzynia lub beczka. Aby dodać poziom do kampanii, dopisz jego ścieżkę w `levels/campaign.json` i uruchom `tests/check_levels.gd`.

## Model ruchu i fizyki

`scripts/physical_model.gd` udostępnia wspólną funkcję `move()` dla gry, podglądu i solvera. Wyznacza stan po ruchu, trasy robota i ciała, koszt energii oraz powód odrzucenia ruchu. Ruch odrzucony nie zmienia stanu ani energii. Model jest kafelkowy: ciała zatrzymują się zawsze na pełnych polach, a pole ma 1 m.

Parametry: masa robota 40 kg, g = 9,81 m/s², d = 1 m.

| Podłoże | μ statyczne skrzyni | μ kinetyczne skrzyni | Opór toczenia beczki | Przyczepność kół robota |
| --- | ---: | ---: | ---: | ---: |
| Drewno, cel, płyta, drzwi, uskok | 0,35 | 0,25 | 0,015 | 0,9 |
| Lód | 0,05 | 0,03 | 0,01 | 0,1 |
| Piasek | 0,75 | 0,65 | 0,30 | 0,6 |

Opór ruszenia beczki to dwukrotność oporu toczenia.

**Siła pchania i przyczepność.** Robot przenosi na ciało co najwyżej `F = min(Fmax, μ_chwytu(pole robota) · m_robota · g)`. Na drewnie decyduje silnik (300 N), na piasku przyczepność (≈ 235 N), a na lodzie robot ma tylko ≈ 39 N. Ciało rusza, gdy `F ≥ m · g · μ_s(pole ciała)`. Przykłady przy Fmax = 300 N:

- skrzynię 35 kg z piasku (257,5 N) ruszy tylko robot stojący na drewnie,
- skrzyni 45 kg leżącej na piasku (331 N) nie da się już ruszyć,
- stojąc na lodzie, robot pchnie skrzynię leżącą na lodzie, ale nie na drewnie,
- skrzynia 75 kg wymaga robota na drewnie (257,5 N).

**Poślizg ciał.** Jeżeli ciało wjeżdża na pole, na którym jego współczynnik kinetyczny jest mniejszy niż 0,10 (skrzynia na lodzie, beczka na drewnie lub lodzie), nadmiar siły staje się energią kinetyczną `E = (F − F_ruszenia) · d`. Ciało sunie dalej, dopóki stoi na śliskim polu. Przejście od środka do środka sąsiedniego pola kosztuje `m · g · (μ_k(skąd) + μ_k(dokąd)) / 2 · d`. Ciało zatrzymuje się na pierwszym nieśliskim polu (jeśli starczy energii, by na nie wjechać), przed przeszkodą albo gdy zabraknie energii. Przykłady: skrzynia 35 kg pchnięta z drewna na lód ma 180 J i wjeżdża na piasek za lodem (117 J), a skrzynia 45 kg zatrzymuje się na ostatnim polu lodu (150 J > 145,5 J). Beczka toczy się po drewnie aż do przeszkody; zatrzymuje ją piasek.

**Poślizg robota.** Robot wjeżdżający na pole o przyczepności mniejszej niż 0,2 (lód) nie może zahamować. Jedzie dalej, aż wjedzie na pole z przyczepnością albo zatrzyma się przed przeszkodą (ścianą, ciałem, zamkniętymi drzwiami). Z rozpędu nie pcha ciał.

**Płyty i drzwi.** Drzwi są otwarte, gdy na każdej płycie leży ciało o masie co najmniej `plate_mass`. Robot nie obciąża płyty. Przy pchnięciu pchane ciało nie liczy się do nacisku, więc nie można zdjąć skrzyni z płyty i przepchnąć jej w tym samym ruchu przez drzwi. Ciało stojące w drzwiach może z nich wyjechać.

**Uskoki.** Na pole `>` `<` `^` `v` może wjechać robot lub ciało poruszające się tylko w kierunku strzałki. Robot, który wpycha ciało, wjeżdża na jego dawne pole, dlatego to pole także musi go przepuścić.

**Energia.** Koszt jest naliczany za udane ruchy:

- krok: `W_robot = m_robota · g · μ_k(pole startowe robota) · d`; ślizg robota nie kosztuje dodatkowo (porusza się z rozpędu),
- pchnięcie: `W_robot + m · g · μ_k(pole startowe ciała) · d` oraz, przy poślizgu, nadana energia `E`.

Krok po drewnie kosztuje 98,1 J, a pchnięcie skrzyni 35 kg z drewna na drewno, gdy robot stoi na drewnie: 183,9375 J.

## Struktura projektu

```text
project.godot                 konfiguracja projektu i scena główna
main.tscn                    scena gry
hud.tscn                     HUD i ekran ukończenia
scripts/game.gd              stan planszy, sterowanie, rysowanie i animacje
scripts/game_hud.gd          obsługa HUD
scripts/level_data.gd        parser poziomów JSON
scripts/campaign.gd          lista poziomów kampanii, odblokowywanie i zapis postępu
scripts/physical_model.gd    przyczepność, pchanie, poślizg, płyty, drzwi, uskoki i energia
scripts/board_state.gd       reprezentacja stanu dla AI
scripts/min_priority_queue.gd kolejka priorytetowa A*
scripts/astar_solver.gd      solver A*
scripts/sokoban_heuristics.gd heurystyki h1, h2 i h3
scripts/solve_cli.gd         uruchamianie solvera bez okna gry
docs/ai_interface.md         kontrakt integracji AI z interfejsem
levels/campaign.json         kolejność poziomów kampanii
levels/campaign/             12 poziomów kampanii
levels/demo_level.json       plansza testowa solvera
levels/win_test.json         test zwycięstwa
tests/                       testy integracyjne, fizyki i weryfikacja poziomów
addons/godot_ai/             dodatek edytora do integracji MCP
```

## Moduł AI
### Reprezentacja stanu dla AI

`scripts/board_state.gd` przechowuje pozycję robota oraz pozycje i masy
skrzyń, niezależnie od interfejsu. Układ ścian, cele i teren pozostają
w `LevelData`. Przykład przygotowania stanów do wyszukiwania:

```gdscript
var initial := BoardState.from_level(level)
# Stan aktualnej rozgrywki: BoardState.new(player_position, boxes)
var candidate := initial.copy()
var visited := {initial.state_key(): true}
```

`state_key()` uwzględnia pozycję robota i masę na każdej pozycji skrzyni,
ale ignoruje kolejność skrzyń w tablicy. Klucze porównujemy w obrębie jednej
planszy i niezmiennych parametrów fizycznych. `copy()` izoluje modyfikacje
symulowanego stanu. `box_positions(index)` pomija pchaną skrzynię i zwraca
słownik zgodny z `PhysicalModel.push_box()`. `is_solved(level)` sprawdza cel.

### Algorytm A*

Kontrakt wejścia/wyjścia i statusy opisuje
[docs/ai_interface.md](docs/ai_interface.md). Gra wywołuje solver ze stanem
`BoardState.new(player_position, boxes)`, czyli z aktualnego układu planszy,
bez jej resetowania. Solver nie zmienia stanu gry podczas wyszukiwania.

`scripts/astar_solver.gd` udostępnia synchroniczne wyszukiwanie bez zależności
od sceny. Kolejka priorytetowa w `scripts/min_priority_queue.gd` używa kopca
binarnego. Algorytm przechowuje najlepsze koszty `g`, porządkuje stany według
`f = g + h` i odtwarza kierunki ruchów przez odnośniki do poprzedników.
Lepsza ścieżka do znanego stanu powoduje jego ponowne dodanie do kolejki.

```gdscript
var solver := AStarSolver.new()
var result := solver.solve(level)
# Plan od aktualnego stanu gry:
var current := BoardState.new(player_position, boxes)
var energy_result := solver.solve(level, current, AStarSolver.CostMode.ENERGY)
if result["success"]:
    var actions = result["actions"] # Array[Vector2i], np. Vector2i.UP
```

Tryb `STEPS` liczy każdy ruch robota jako 1, również pchnięcie z poślizgiem.
Domyślna heurystyka to Manhattan z przeskalowaniem opisanym poniżej. Tryb `ENERGY`
korzysta z kosztu każdego ruchu zwracanego przez `PhysicalModel.move()`.
Tej samej funkcji używa rozgrywka, więc AI i animacje otrzymują ten sam
stan końcowy po poślizgu. Heurystyka w trybie `ENERGY` jest wyrażona w dżulach.

Koszty kroków i pchnięć są opisane w sekcji [Model ruchu i fizyki](#model-ruchu-i-fizyki).
Poślizg zużywa nadaną energię przez tarcie na kolejnych polach; nie doliczamy
tych strat ponownie do pracy robota. Reszta energii jest tracona przy
zderzeniu lub zatrzymaniu na nieśliskim podłożu.

Solver odrzuca stany, w których skrzynia lub beczka trafiła do narożnika
(ściany z dwóch prostopadłych stron) poza celem: takiego ciała nie da się już
pchnąć, bo robot musiałby stanąć w ścianie, niezależnie od podłoża. Jeśli
ciał jest więcej niż celów, stan jest odrzucany dopiero wtedy, gdy ruchomych
ciał zostało mniej niż celów. Odcinanie nie usuwa żadnego rozwiązania.

Czwarty argument `solve` przyjmuje opcjonalny `Callable(state, level)`
zwracający heurystykę w jednostkach wybranego kosztu. Aby zachować
optymalność, heurystyka musi być dopuszczalna. Aby uruchomić Dijkstrę,
przekaż `func(_state, _level): return 0.0` jako czwarty argument.

### Heurystyka Manhattan

`scripts/sokoban_heuristics.gd` zawiera geometryczną funkcję `manhattan`
oraz fabrykę `manhattan_for(level, energy_cost)`, zwracającą `Callable`
dopasowany do fizyki i jednostek kosztu. A* używa go domyślnie.

Dla każdego ciała liczymy `di = min_cel(|x - x_celu| + |y - y_celu|)`.
Gdy ciał jest więcej niż celów, sumujemy tylko tyle najmniejszych wartości,
ile jest celów (nadmiarowe ciała mogą zostać na miejscu).
Ignorujemy ściany, pozostałe skrzynie i wyłączność przypisania celów,
więc kilka skrzyń może wybrać ten sam najbliższy cel. Jest to dolne
oszacowanie, a nie pełne przypisanie skrzyń do celów.

- Bez lodu: `h_steps = suma(di)`.
- Ze śliskim terenem albo z beczkami (toczą się także po drewnie):
  `h_steps = suma(ceil(di / L))`, gdzie
  `L = max(1, szerokość - 1, wysokość - 1)` ogranicza maksymalną drogę
  skrzyni podczas jednego pchnięcia. Dzięki temu poślizg przez kilka pól
  nie powoduje zawyżenia oszacowania liczby ruchów.
- W energii: `h_energy = h_steps * m_robot * g * mu_k,min * d`.
  Minimalne tarcie pochodzi z przechodnich pól planszy. Każde pchnięcie
  kosztuje przynajmniej tę pracę robota, więc skala jest dolnym
  oszacowaniem kosztu w J. Masa skrzyń i energia poślizgu są tutaj pomijane.

Heurystyka jest dopuszczalna dla obecnego modelu ruchu. Przykładowo na
`win_test.json`: odległość Manhattan wynosi 1, oszacowanie energetyczne
98,1 J, a rozwiązanie to jeden ruch w górę o rzeczywistym koszcie
183,9375 J. Przy poślizgu przez trzy pola odległość geometryczna 3 może
odpowiadać jednemu pchnięciu. Skalowanie na planszach z lodem jest celowo
zachowawcze.

### Heurystyki fizyczne h2 i h3

**h2 — masa i tarcie** (`weighted_for`) szacuje liczbę pchnięć z odległości
Manhattan. Osobno wyznacza górną granicę przesunięcia skrzyni i beczki podczas
jednego pchnięcia. W trybie energii mnoży liczbę pchnięć przez sumę najmniejszej
pracy robota i najmniejszej pracy potrzebnej do przemieszczenia danego ciała
o jedno pole. Praca ciała zależy od jego masy oraz najniższego tarcia lub oporu
toczenia na planszy.

**h3 — Terrain-Aware** (`terrain_aware_for`) buduje graf pchnięć osobno
dla każdej kombinacji rodzaju i masy ciała. Zachowuje ściany, kierunki
uskoków, ograniczenia siły i reguły poślizgu. Przyjmuje, że drzwi są otwarte,
a robot może znaleźć się po dowolnej dostępnej stronie ciała. Każde pole
na trasie pchnięcia jest dopuszczalnym miejscem zatrzymania, ponieważ w grze
przeszkoda może skrócić ślizg. Koszt krawędzi wynosi jeden ruch albo energię
pchnięcia z modelu fizycznego. Odległości do najbliższego celu powstają przez
wielopunktowe wyszukiwanie Dijkstry od celów po odwróconych krawędziach.

Obie heurystyki sumują najniższe oszacowania dla tylu ciał, ile jest celów.
Pominięcie kosztu dojścia robota i dopuszczenie wspólnego celu dla kilku ciał
zachowują dolne oszacowanie. Jeśli w grafie h3 za mało ciał może dotrzeć do
jakiegokolwiek celu, solver otrzymuje skończoną wartość z h2.

### Wynik wyszukiwania

Wynik zawiera `status`, `success`, `actions`, `moves`, `cost`, `energy`,
`elapsed_ms`, `expanded_states` i `discovered_states`. Możliwe statusy:
`solved`, `no_solution`, `state_limit`, `time_limit`, `invalid_input`
oraz `invalid_heuristic`. Brak rozwiązania ma koszt `INF`.
Domyślne limity to 100000 rozwinięć i 5000 ms (argumenty piąty i szósty).
Osiągnięcie limitu nie oznacza, że plansza jest nierozwiązywalna.
Wywołanie blokuje wątek do zakończenia. Gra przekazuje własny limit czasu
30 000 ms, a CLI używa domyślnego limitu 5000 ms, o ile nie podano innego.

### Uruchomienie solvera bez okna gry

Z katalogu projektu (zastąp `godot` ścieżką do programu Godot, jeśli nie ma go w `PATH`):

```text
godot --headless --path . --script res://scripts/solve_cli.gd -- res://levels/win_test.json energy 100000 5000 h3
```

Po ścieżce poziomu można podać tryb `steps` lub `energy`, limit rozwinięć,
limit czasu w ms i heurystykę `h1`, `h2`, `h3` lub `dijkstra` (heurystyka zerowa).
Domyślne wartości to `steps`, `100000`, `5000` i `h1`.
Wynik JSON zawiera nazwę heurystyki, a akcje mają postać kierunków
`[dx, dy]`. Godot może wcześniej wypisać komunikaty startowe.
CLI zwraca kod `0` dla rozwiązania, `1` dla braku rozwiązania
lub osiągnięcia limitu i `2` dla nieprawidłowego wejścia lub heurystyki.
`demo_level.json` wymaga przy obecnej fizyce więcej niż 100 000 rozwinięć,
np. `1000000` stanów i `120000` ms.

## Testy

Wszystkie polecenia uruchamia się z katalogu projektu (zastąp `godot` ścieżką do programu):

```text
godot --headless --path . --script res://tests/physics_test.gd
godot --headless --path . --script res://tests/game_integration_test.gd
godot --headless --path . --script res://tests/check_levels.gd -- -1 energy h3
```

- `physics_test.gd` — przyczepność, poślizg robota i ciał, piasek, beczki, płyty i drzwi, uskoki, reguły solvera oraz zapis postępu kampanii.
- `game_integration_test.gd` — sterowanie, HUD, odtwarzanie planu AI, ukończenie poziomu 1 i odblokowanie poziomu 2. Używa osobnego pliku `user://test_progress.cfg`, więc nie zmienia postępu gracza.
- `check_levels.gd` — rozwiązuje poziomy kampanii (limit 3 mln stanów) i wypisuje długość planu, pchnięcia, stany rozwinięte i odkryte, energię, czas oraz wynik porównania z limitami gry. Opcjonalne argumenty to `-- <indeks|-1> [steps|plan|trace|energy] [h1|h2|h3|dijkstra]`. Indeksy zaczynają się od zera, a `-1` wybiera całą kampanię. Opcja `trace` rysuje planszę po każdym pchnięciu i poślizgu.

## Dalszy rozwój

Kolejne elementy, które można dodać do projektu:

- wykrywanie deadlocków bardziej złożonych niż narożniki,
- panel parametrów fizycznych,
- porównanie strategii AI i ustawień fizyki w eksperymentach,
- planowanie asynchroniczne, aby okno gry pozostawało responsywne podczas wyszukiwania.
