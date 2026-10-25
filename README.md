# Sokoban AI

Projekt gry Sokoban 2D w Godot Engine 4.7.2 (GDScript). Można grać ręcznie albo uruchomić z HUD solver A*, który wybiera plan o najmniejszej liczbie ruchów lub najniższym koszcie energii. Gra i solver korzystają z tego samego modelu pchania, tarcia i poślizgu. Planer można też uruchomić bez okna gry. Dodatkowe heurystyki, wykrywanie deadlocków i eksperymenty porównawcze pozostają do zrobienia.

## Uruchomienie

1. Otwórz katalog repozytorium jako projekt w Godot 4.7.2 (`project.godot`).
2. Uruchom projekt klawiszem `F5`. Sceną główną jest `main.tscn`.

Do samej gry nie są potrzebne zewnętrzne grafiki: plansza, gracz i skrzynie są rysowane programowo.

## Sterowanie i interfejs

| Klawisz lub element HUD | Działanie |
| --- | --- |
| `WASD` lub strzałki | Ruch gracza i pchanie skrzyni |
| `R` lub **Resetuj poziom** | Ponowne wczytanie bieżącego poziomu |
| **Poziom** | Wybór demonstracji fizyki albo testu zwycięstwa |
| **Najmniej ruchów** / **Najmniej energii** | Wybór kosztu planowania A*: `STEPS` / `ENERGY` |
| **Rozwiąż AI** | Wyznaczenie planu od aktualnego stanu planszy i rozpoczęcie odtwarzania |
| **Zatrzymaj AI** | Zatrzymanie kolejnych akcji planu; trwająca animacja kończy się bez przerywania |

HUD pokazuje liczbę wykonanych ruchów, zużytą energię, maksymalną siłę robota i komunikat o ostatnim działaniu. Ruch gracza i skrzyni jest animowany; poślizg skrzyni przebiega przez kolejne pola wyznaczone przez model fizyczny. Podczas animacji i po ukończeniu poziomu kolejne ruchy są blokowane.

Sekcja AI pokazuje status i statystyki ostatniego wyszukiwania: tryb kosztu, czas w ms, liczbę rozwiniętych i odkrytych stanów, długość planu oraz jego energię. Po znalezieniu rozwiązania każda akcja planu przechodzi przez tę samą funkcję ruchu i model fizyczny co ruch ręczny; następna akcja rozpoczyna się dopiero po zakończeniu animacji. Nieudany ruch AI przerywa odtwarzanie i wyświetla jego powód. Podczas odtwarzania `WASD` i strzałki są ignorowane, ale `R` nadal resetuje poziom. Reset i zmiana poziomu usuwają plan oraz statystyki AI; zatrzymanie odtwarzania zachowuje statystyki ostatniego wyszukiwania.

Wyszukiwanie jest synchroniczne: napis „Planowanie...” może pojawić się przed wywołaniem solvera, lecz okno gry nie reaguje podczas samego obliczania planu. Gra przekazuje limit 100 000 rozwiniętych stanów i 30 000 ms. Osiągnięcie limitu czasu lub stanów oznacza, że nie ustalono rozwiązywalności planszy, a nie że rozwiązanie nie istnieje.

Po umieszczeniu wszystkich skrzyń na celach pojawia się ekran ukończenia z liczbą ruchów i energią. Można zagrać ponownie albo zamknąć komunikat. Zamknięcie komunikatu nie odblokowuje ruchu na ukończonym poziomie; można go zresetować lub wybrać inny.

## Poziomy

| Plik | Zawartość | Przeznaczenie |
| --- | --- | --- |
| `levels/demo_level.json` | Dwie skrzynie (35 i 45 kg), dwa cele, lód i piasek | Demonstracja pchania, tarcia i poślizgu oraz plansza dla solvera. |
| `levels/win_test.json` | Jedna skrzynia (35 kg) i jeden cel | Krótki test ekranu ukończenia. |

Poziomy są wczytywane z JSON przez `scripts/level_data.gd`. Pole `map` to tablica wierszy; `robot_force` określa maksymalną siłę robota w niutonach (domyślnie 300), a wpisy `boxes` ustawiają masę skrzyni według jej indeksu w kolejności odczytu mapy (domyślnie 35 kg).

| Znak mapy | Znaczenie |
| --- | --- |
| `#` | Ściana |
| `.` | Zwykłe podłoże |
| `G` | Cel |
| `P` | Pozycja startowa gracza |
| `B` | Skrzynia |
| `*` | Skrzynia na celu |
| `I` | Lód |
| `S` | Piasek |

W kodzie gry dostępne poziomy są wymienione w `LEVEL_PATHS` w `scripts/game.gd`, a ich nazwy w selektorze HUD w `scripts/game_hud.gd`. Samo dodanie pliku JSON nie dodaje jeszcze pozycji do menu.

## Model ruchu i fizyki

`scripts/physical_model.gd` udostępnia wspólną funkcję `move()` dla gry i solvera. Sprawdza, czy siła robota wystarcza do ruszenia skrzyni, czy pole docelowe jest wolne, oraz wyznacza końcowy stan, trasę poślizgu i koszt energetyczny ruchu. Gracz nie przechodzi przez ściany ani przez zablokowane skrzynie. Koszt energii jest naliczany za udane kroki i pchnięcia, w tym energię nadaną do poślizgu.

Model przyjmuje masę robota 20 kg, przyspieszenie ziemskie 9,81 m/s² i długość pola 1 m. Współczynniki tarcia zapisane w kodzie:

| Podłoże | Tarcie statyczne | Tarcie kinetyczne |
| --- | ---: | ---: |
| Zwykłe pole i cel | 0,35 | 0,25 |
| Lód | 0,05 | 0,03 |
| Piasek | 0,75 | 0,65 |

## Struktura projektu

```text
project.godot                 konfiguracja projektu i scena główna
main.tscn                    scena gry
hud.tscn                     HUD i ekran ukończenia
scripts/game.gd              stan planszy, sterowanie, rysowanie i animacje
scripts/game_hud.gd          obsługa HUD
scripts/level_data.gd        parser poziomów JSON
scripts/physical_model.gd    reguły pchania i koszt energii
scripts/board_state.gd       reprezentacja stanu dla AI
scripts/min_priority_queue.gd kolejka priorytetowa A*
scripts/astar_solver.gd      solver A*
scripts/sokoban_heuristics.gd heurystyka Manhattan
scripts/solve_cli.gd         uruchamianie solvera bez okna gry
docs/ai_interface.md         kontrakt integracji AI z interfejsem
levels/demo_level.json       demonstracja fizyki
levels/win_test.json         test zwycięstwa
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

Koszty zaimplementowane w `PhysicalModel` (d = 1 m):

- Zwykły krok: `W_robot = m_robot * g * mu_k(pole startowe robota) * d`.
- Pchnięcie: `W_robot + m_skrzyni * g * mu_k(pole startowe skrzyni) * d`.
- Przy wjeździe skrzyni na lód doliczana jest energia nadana do poślizgu:
  `E_start = max(0, Fmax - Fstart) * d`.

Poślizg zużywa nadaną energię przez tarcie na kolejnych polach; nie doliczamy
tych strat ponownie do pracy robota. Reszta energii jest tracona przy
zderzeniu lub zatrzymaniu na nieśliskim podłożu. To uproszczony model
kafelkowy: skrzynia zatrzymuje się na pełnych polach, a siła robota ogranicza
ruszenie skrzyni z miejsca. Ruch odrzucony nie zmienia stanu ani energii.
Przykładowo krok po drewnie kosztuje 49,05 J, a pchnięcie skrzyni 35 kg
z drewna na drewno, gdy robot też stoi na drewnie: 134,8875 J.

Czwarty argument `solve` przyjmuje opcjonalny `Callable(state, level)`
zwracający heurystykę w jednostkach wybranego kosztu. Aby zachować
optymalność, heurystyka musi być dopuszczalna. Aby uruchomić Dijkstrę,
przekaż `func(_state, _level): return 0.0` jako czwarty argument.

### Heurystyka Manhattan

`scripts/sokoban_heuristics.gd` zawiera geometryczną funkcję `manhattan`
oraz fabrykę `manhattan_for(level, energy_cost)`, zwracającą `Callable`
dopasowany do fizyki i jednostek kosztu. A* używa go domyślnie.

Dla każdej skrzyni liczymy `di = min_cel(|x - x_celu| + |y - y_celu|)`.
Ignorujemy ściany, pozostałe skrzynie i wyłączność przypisania celów,
więc kilka skrzyń może wybrać ten sam najbliższy cel. Jest to dolne
oszacowanie, a nie pełne przypisanie skrzyń do celów.

- Bez lodu: `h_steps = suma(di)`.
- Ze śliskim terenem: `h_steps = suma(ceil(di / L))`, gdzie
  `L = max(1, szerokość - 1, wysokość - 1)` ogranicza maksymalną drogę
  skrzyni podczas jednego pchnięcia. Dzięki temu poślizg przez kilka pól
  nie powoduje zawyżenia oszacowania liczby ruchów.
- W energii: `h_energy = h_steps * m_robot * g * mu_k,min * d`.
  Minimalne tarcie pochodzi z przechodnich pól planszy. Każde pchnięcie
  kosztuje przynajmniej tę pracę robota, więc skala jest dolnym
  oszacowaniem kosztu w J. Masa skrzyń i energia poślizgu są tutaj pomijane.

Heurystyka jest dopuszczalna dla obecnego modelu ruchu. Przykładowo na
`win_test.json`: odległość Manhattan wynosi 1, oszacowanie energetyczne
49,05 J, a rozwiązanie to jeden ruch w górę o rzeczywistym koszcie
134,8875 J. Przy poślizgu przez trzy pola odległość geometryczna 3 może
odpowiadać jednemu pchnięciu. Skalowanie na planszach z lodem jest celowo
zachowawcze; osobne heurystyki fizyczne pozostają do zaimplementowania.

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
godot --headless --path . --script res://scripts/solve_cli.gd -- res://levels/win_test.json energy 100000 5000
```

Argumenty po `--` to: ścieżka do poziomu, opcjonalny tryb `steps` lub `energy`,
limit rozwinięć i limit czasu w ms. Domyślne wartości to `steps`, `100000`
i `5000`. Wynik jest wypisywany jako JSON (po ewentualnych komunikatach
startowych Godota); akcje mają postać kierunków
`[dx, dy]`. CLI zwraca kod `0` dla rozwiązania, `1` dla braku rozwiązania
lub osiągnięcia limitu i `2` dla nieprawidłowego wejścia lub heurystyki.
`demo_level.json` w trybie `energy` może wymagać większego limitu czasu,
np. `30000` ms.

## Dalszy rozwój

Kolejne elementy, które można dodać do projektu:

- heurystyki fizyczne dla A*,
- wykrywanie deadlocków,
- więcej plansz o rosnącej trudności,
- panel parametrów fizycznych,
- porównanie strategii AI i ustawień fizyki w eksperymentach,
- planowanie asynchroniczne, aby okno gry pozostawało responsywne podczas wyszukiwania.
