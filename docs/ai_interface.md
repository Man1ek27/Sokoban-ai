# Interfejs AI dla warstwy Godot

Kontrakt v1 odpowiada aktualnej implementacji i jest gotowy do uzgodnienia
między Radosławem (AI), Alicją (interfejs) i Mariuszem (fizyka).

## Wejście do planera

```gdscript
var result: Dictionary = AStarSolver.new().solve(
    level,           # LevelData: ściany, cele, teren, siła robota
    initial_state,   # BoardState albo null: wtedy stan początkowy poziomu
    cost_mode,       # AStarSolver.CostMode.STEPS lub ENERGY
    heuristic,       # Callable(state, level) lub Callable(): Manhattan
    max_expanded,    # int > 0; domyślnie 100000
    time_limit_ms    # int > 0; domyślnie 5000
)
```

Współrzędne są indeksami kafelków: `(0, 0)` w lewym górnym rogu,
`x` rośnie w prawo, `y` w dół. Nie przekazujemy pozycji w pikselach.
Stan zawiera `player_position: Vector2i` i `boxes: Array[Dictionary]`.
Każda skrzynia ma `position: Vector2i` oraz dodatnią, skończoną `mass: float` w kg.
Skrzynie nie mogą się nakładać ani stać na ścianach, robot musi być na wolnym
polu. Wymagana jest równa, niezerowa liczba skrzyń i celów.

Parametr siły to `level.robot_force` w N. UI ustawia go przed planowaniem
i tworzy dla odtwarzania `PhysicalModel.new(level.robot_force)`.
Solver kopiuje stan wejściowy i nie zmienia planszy ani obiektów gry.
Podczas planowania plansza, masy i parametry fizyki muszą być niezmienne.
Zmiana poziomu, siły, stanu robota lub skrzyń unieważnia wcześniej obliczony plan.

Heurystyka zwraca nieujemne, skończone oszacowanie w jednostkach wybranego
kosztu. Domyślny Manhattan jest odpowiednio skalowany. Własna heurystyka
musi być dopuszczalna, jeżeli wymagane jest rozwiązanie optymalne.

## Wynik

Wynik jest słownikiem o następujących polach:

| Pole | Typ | Znaczenie |
|---|---|---|
| `status` | `String` | Powód zakończenia, tabela poniżej |
| `success` | `bool` | `true` wyłącznie dla `solved` |
| `actions` | `Array` elementów `Vector2i` | Kierunki kolejnych ruchów robota |
| `moves` | `int` | Długość znalezionego planu |
| `cost` | `float` | Suma kosztów: ruchy w STEPS, J w ENERGY |
| `energy` | `float` | Energia znalezionego planu w J w obu trybach |
| `elapsed_ms` | `float` | Czas planowania w ms |
| `expanded_states` | `int` | Liczba rozwinięć stanów; ponowne rozwinięcie jest liczone ponownie |
| `discovered_states` | `int` | Liczba różnych kluczy stanów z zapisanym kosztem g |

| Status | Interpretacja dla UI |
|---|---|
| `solved` | Plan gotowy; można rozpocząć odtwarzanie |
| `no_solution` | Przeszukano wszystkie dostępne stany bez rozwiązania |
| `time_limit` | Upłynął limit czasu; rozwiązywalność pozostaje nieznana |
| `state_limit` | Osiągnięto limit rozwinięć; rozwiązywalność pozostaje nieznana |
| `invalid_input` | Nieprawidłowa plansza, stan lub parametry |
| `invalid_heuristic` | Heurystyka zwróciła wartość ujemną albo nieskończoną/NaN |

Gdy `success == false`: `actions == []`, `moves == 0`, `cost == INF`,
`energy == 0.0`. Metryki wyszukiwania nadal są dostępne. Energia 0 nie oznacza
rozwiązania bez kosztu. Dla planszy już rozwiązanej: `solved` z pustym planem
i zerowymi kosztami. UI zawsze sprawdza `success`, a nie samą długość planu.

## Przykład wywołania z rozgrywki

```gdscript
var initial := BoardState.new(player_position, boxes)
var result := AStarSolver.new().solve(
    level, initial, AStarSolver.CostMode.ENERGY
)
if result["success"]:
    var actions: Array = result["actions"]
    # Zachowaj plan i wykonuj po jednym kierunku po zakończeniu animacji.
else:
    var message: String = result["status"]
```

Jedna akcja jest jednym krokiem robota w jednym z czterech kierunków:
góra `(0, -1)`, dół `(0, 1)`, lewo `(-1, 0)`, prawo `(1, 0)`.
Może zawierać pchnięcie i poślizg skrzyni przez kilka pól.
Plan nie zawiera bezpośrednich poleceń przesuwania skrzyń.

Dla każdej akcji warstwa gry wywołuje
`physics.move(current_state, direction, level)`. Sukces zwraca:

- `state: BoardState`: końcowy stan logiczny;
- `energy: float`: koszt tego ruchu w J;
- `box_index: int`: indeks pchniętej skrzyni albo `-1` dla chodzenia;
- `path: Array[Vector2i]`: kolejne pozycje skrzyni do animowania;
- przy pchnięciu dodatkowo `position: Vector2i` i `terrain: String`.

Odrzucony ruch zwraca `success: false` oraz `reason: String` i nie zmienia
stanu wejściowego. Należy wtedy przerwać odtwarzanie i ponownie zaplanować.
Gra nalicza energię z wyniku `move`, a nie oblicza jej ponownie w UI.
Najpierw ustala stan logiczny, następnie animuje zwróconą ścieżkę.
Kolejną akcję wykonuje dopiero po zakończeniu animacji; `_try_move` w `game.gd`
odrzuca wejście w trakcie animacji. Reset lub zmiana parametrów usuwa plan.

`solve()` jest synchroniczne, blokuje wywołujący wątek i nie wysyła zdarzeń
postępu ani nie obsługuje anulowania w trakcie wyszukiwania. Limity dotyczą
pętli wyszukiwania, nie są przerwaniem wykonywanej właśnie operacji.
Do responsywnego UI potrzebny będzie osobny wątek z niezależną kopią danych;
wynik i animacje należy obsługiwać w głównym wątku. Na tym etapie nie ma
przycisków sterowania AI ani odtwarzacza planu w interfejsie.

## Uruchomienie bez interfejsu graficznego

Z katalogu projektu (zastąp `godot` ścieżką do swojego pliku wykonywalnego):

```text
godot --headless --path . --script res://scripts/solve_cli.gd -- res://levels/win_test.json energy 100000 5000
```

Argumenty po `--`: plik poziomu, opcjonalny tryb `steps`/`energy`, opcjonalny
limit rozwinięć i limit czasu w ms. Domyślne wartości: `steps`, `100000`, `5000`.
Masy, siła i układ planszy pochodzą z pliku poziomu. CLI planuje od jego
stanu początkowego i używa heurystyki Manhattan.

CLI nie ładuje sceny gry ani HUD. Wypisuje jeden obiekt JSON z wynikiem;
komunikaty startowe Godota i autoloadów mogą pojawić się przed JSON-em.
W JSON kierunki mają postać `[dx, dy]`, a brak skończonego kosztu to `null`.
Dodatkowe pola to `cost_mode` (`steps`/`energy`) i `cost_unit` (`moves`/`J`).
Błędy argumentów lub odczytu pliku zwracają skrócony obiekt z `success`,
`status: "invalid_input"` i `message`.

Przykładowy wynik dla `win_test.json` w trybie energii (czas zależy od uruchomienia):

```json
{"status":"solved","success":true,"actions":[[0,-1]],"moves":1,"cost":134.8875,"energy":134.8875,"elapsed_ms":0.3,"expanded_states":4,"discovered_states":11,"cost_mode":"energy","cost_unit":"J"}
```

Kody wyjścia: `0` rozwiązanie, `1` brak rozwiązania lub osiągnięty limit,
`2` nieprawidłowe wejście albo heurystyka.

Na nowym komputerze najpierw otwórz projekt w edytorze, aby Godot
zaimportował zasoby i zarejestrował klasy. Można też zrobić to bez okna:

```text
godot --headless --editor --path . --import
```
