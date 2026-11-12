# Benchmark A* — STEPS i ENERGY

## Cel i zakres

Porównanie skuteczności i kosztu wyszukiwania A* na kampanii z
`Campaign.level_paths()`. Domyślnie: wszystkie 12 poziomów, STEPS i ENERGY,
3 powtórzenia każdego wariantu (72 wyszukiwania). Benchmark nie zmienia solvera,
fizyki, poziomów ani postępów kampanii. Nie tworzy instancji `Campaign`, która
wczytywałaby postęp; korzysta wyłącznie z jej statycznego manifestu.

Każdy pomiar tworzy nowy poziom z JSON, stan początkowy, solver i heurystykę.
Powtórzenia nie współdzielą struktur wyszukiwania. Wykonywane są kolejno,
w jednym procesie Godota, bez rozgrzewki. Kolejność: numer poziomu, STEPS/ENERGY,
heurystyka, numer powtórzenia. Pomiary czasu nie obejmują wczytania JSON,
przygotowania heurystyki, niezależnej walidacji ani eksportu CSV.

## Środowisko eksperymentu

Przed wykorzystaniem danych w sprawozdaniu uzupełnij:

| Pole | Wartość |
| --- | --- |
| CPU, liczba rdzeni/wątków | do uzupełnienia |
| RAM | do uzupełnienia |
| System operacyjny i wersja | do uzupełnienia (pomiar roboczy: Windows) |
| Godot, wersja i rodzaj wydania | pomiar roboczy: 4.7.2.stable.official.ed1daf0bf, headless |
| Commit repozytorium i lokalne zmiany | do uzupełnienia; zachowaj także skrypty eksperymentu |
| Tryb zasilania, obciążenie, aplikacje w tle | do uzupełnienia |
| Data, pełna komenda | data UTC w CSV; zapisz komendę poniżej lub w protokole |

Czas wyszukiwania zależy od komputera, obciążenia systemu, temperatury i trybu
zasilania. Nie porównuj bezpośrednio czasów z różnych środowisk. Podczas pomiaru
unikaj równoległego uruchamiania testów i innych obliczeń. W CSV zapisywane są
wersja Godota, czas rozpoczęcia UTC, ścieżka i SHA-256 pliku poziomu oraz limity.
Skrót poziomu nie zastępuje identyfikacji wersji kodu solvera i fizyki.

## Uruchamianie

W katalogu projektu, z Godotem w `PATH` (w PowerShell dla pełnej ścieżki
użyj `& 'C:\ścieżka\Godot_console.exe'` zamiast `godot`):

```powershell
# Pierwszy import w świeżym checkout, przed pomiarami:
godot --headless --path . --editor --import

# Szybki test poziomów 1–3, oba tryby, trzy powtórzenia:
godot --headless --path . --script res://tests/benchmark.gd -- --levels 1-3 --output results/quick_raw.csv

# Pełna kampania z domyślnymi limitami i trzema powtórzeniami:
godot --headless --path . --script res://tests/benchmark.gd

# Własny wybór i parametry:
godot --headless --path . --script res://tests/benchmark.gd -- --levels 1,3,5-7 --mode energy --repeats 5 --time-limit-ms 30000 --max-expanded 100000 --output results/custom_raw.csv

# Kontrolowany przypadek przerwania przez limit (zachowuje state_limit):
godot --headless --path . --script res://tests/benchmark.gd -- --levels 1 --repeats 1 --max-expanded 1 --output results/limited_raw.csv

# Testy:
godot --headless --path . --script res://tests/benchmark_test.gd
godot --headless --path . --script res://tests/physics_test.gd
godot --headless --path . --script res://tests/game_integration_test.gd
```

Argumenty po `--` mają postać par `--opcja wartość`; `--help` wypisuje pomoc.

| Opcja | Domyślnie | Znaczenie |
| --- | --- | --- |
| `--levels` | `all` | Numery od **1**, lista i zakresy np. `1-3,5`; duplikaty usuwane, kolejność rosnąca |
| `--mode` | `both` | `steps`, `energy`, `both`; wielkość liter dowolna |
| `--repeats` | `3` | Dodatnia liczba niezależnych wyszukiwań |
| `--time-limit-ms` | `30000` | Limit pojedynczego wyszukiwania w ms, taki jak w grze |
| `--max-expanded` | `100000` | Limit rozwiniętych stanów, taki jak w grze |
| `--output` | `res://results/benchmark_raw.csv` | Ścieżka surowego CSV; względna względem projektu, `res://` lub absolutna |

Dla `name_raw.csv` powstaje `name_summary.csv`; dla `name.csv` powstaje
`name_summary.csv`. Katalogi są tworzone automatycznie. Istniejące pliki wyników
pod wskazanymi ścieżkami są nadpisywane, więc dla osobnych eksperymentów używaj
osobnych nazw. Domyślne pliki to `results/benchmark_raw.csv` i
`results/benchmark_summary.csv`. Surowe wiersze są opróżniane na dysk po każdym
pomiarze; podsumowanie po ukończeniu całej grupy powtórzeń.

Kod wyjścia: `0` — wykonano eksperyment (także z limitami lub `no_solution`),
`1` — błąd walidacji planu, niepoprawne wejście/heurystyka zgłoszone przez solver
lub błąd zapisu CSV, `2` — błędne argumenty, brak manifestu lub błąd otwarcia
plików wynikowych. Błąd walidacji jest raportowany na stderr i w CSV, a pozostałe
pomiary są kontynuowane. Limity nigdy nie są automatycznie zwiększane.

## Heurystyka i jednostki

Uruchamiana jest wyłącznie istniejąca `manhattan`, przez
`SokobanHeuristics.manhattan_for(level, energy_mode)`. Ta fabryka uwzględnia
poślizg i beczki, a w ENERGY skaluje oszacowanie do jednostek energii. STEPS
minimalizuje liczbę akcji, ENERGY koszt w J. Benchmark nie używa surowej
odległości Manhattan jako kosztu w J.

Nową, rzeczywiście zaimplementowaną heurystykę można dodać do słownika
`_heuristic_factories()` w `tests/benchmark.gd`: nazwa → Callable fabryki
`(level, energy_mode) -> Callable(state, level) -> float`. Reszta pomiarów,
walidacji i agregacji działa osobno dla każdej nazwy. h2/h3 obecnie nie istnieją
w rejestrze i nie otrzymują żadnych wyników.

## Metryki surowe

| Kolumny | Definicja |
| --- | --- |
| `level_number`, `level_name`, `level_path`, `level_sha256` | Pozycja w manifeście od 1, nazwa JSON, źródło i skrót pliku |
| `cost_mode`, `heuristic`, `repeat` | STEPS/ENERGY, rzeczywista heurystyka, powtórzenie od 1 |
| `status`, `success` | Oryginalne wartości solvera; `solved`, `no_solution`, `state_limit`, `time_limit`, ewentualnie błędy |
| `moves` | `result["moves"]`: liczba akcji kierunkowych, nie liczba przebytych pól |
| `pushes` | Liczba odtworzonych akcji z `box_index >= 0`; długi poślizg to jedno pchnięcie |
| `energy_j` | `result["energy"]`: energia całego planu w J |
| `objective_cost` | `result["cost"]`: liczba akcji w STEPS lub energia w J w ENERGY |
| `expanded_states` | Licznik rozwinięć zwrócony przez solver, nie pomiar pamięci |
| `discovered_states` | Liczba różnych kluczy stanów w `best_g` solvera |
| `search_ms` | `result["elapsed_ms"]`, czas wyszukiwania mierzony przez solver |
| `replay_valid`, `validation_error` | Poprawność odtworzenia oraz opis wykrytych błędów |
| `replay_moves`, `replay_energy_j` | Liczba wykonanych akcji i suma energii niezależnego odtworzenia |
| `plan_actions` | Sekwencja U/D/L/R do porównywania planów, również przy równych kosztach |
| `max_expanded`, `time_limit_ms`, `godot_version`, `started_utc` | Konfiguracja i początek pomiaru (UTC) |

Nieudane wyszukiwanie zachowuje swoje liczniki, czas i status, ale pola planu
oraz walidacji pozostają puste (brak wartości), zamiast zerowych domyślnych
wartości solvera. `false` walidacji oznacza rzeczywisty błąd znalezionego planu;
puste pole oznacza, że nie było planu do weryfikacji.

## Weryfikacja planu

Każdy sukces solvera jest odtwarzany od kopii stanu początkowego z nowym
`PhysicalModel(level.robot_force)`. Każda akcja przechodzi przez `move()` i musi
zakończyć się sukcesem; kolejnym stanem jest pełne `transition["state"]`.
Uwzględnia to poślizg robota, skrzyń i beczek, płyty, drzwi i uskoki bez
powielania zasad fizyki. Stan końcowy musi spełniać `is_solved(level)`, liczba
akcji musi odpowiadać `result["moves"]`, energia — `result["energy"]`, a koszt
celu — liczbie akcji lub energii zgodnie z trybem. Pchnięcia są zliczane
wyłącznie z rzeczywistych `box_index` przejść. Solver nie raportuje osobnego
licznika pchnięć do porównania.

Tolerancja energii i kosztu: `abs(a-b) <= 1e-6 + 1e-9 * max(abs(a), abs(b))`;
wartości nieskończone i NaN są odrzucane. Kontrolowany jest również brak mutacji
stanu początkowego. Walidacja jest niezależna od rekonstrukcji planu solvera,
ale świadomie używa tego samego modelu fizycznego; nie dowodzi poprawności
samego modelu ani globalnej optymalności planu.

## Agregacja

Grupa: poziom × tryb × heurystyka. `search_ms_median` jest medianą czasu
**wszystkich** powtórzeń w grupie, także nieudanych; przy parzystej liczbie
próbek to średnia dwóch środkowych. Podawane są też minimum i maksimum.
Nie interpretuj czasu zakończenia limitem jako czasu znalezienia rozwiązania.

`solved_count` i `valid_plan_count` informują o liczbie sukcesów i poprawnych
odtworzeń. `status_consistent` sprawdza zgodność statusów, a `plan_consistent`
statusów, sukcesu, długości, pchnięć, energii, kosztu, sekwencji akcji i walidacji.
Pozostałe metryki zachowują wspólną wartość, jeśli powtórzenia są identyczne.
Jeśli się różnią, komórka zawiera tablicę JSON w kolejności powtórzeń, łącznie
z `null` dla brakujących wyników, np. `[22,null,22]`. Dotyczy to także liczników
stanów i błędów walidacji. Rozbieżności nie są zastępowane średnią lub wybranym
„najlepszym” wynikiem. Wersja, limity i identyfikacja poziomu są wspólne,
`started_utc` w podsumowaniu oznacza początek pierwszego powtórzenia.

CSV używa UTF-8, separatora przecinkowego, angielskich nagłówków, kropki
dziesiętnej i standardowego cytowania pól przez `FileAccess.store_csv_line()`.
Przy imporcie do polskiego arkusza wybierz przecinek jako separator i kropkę
jako separator dziesiętny; tablice JSON pozostaw jako tekst.

## Ograniczenia interpretacji

Trzy powtórzenia i mediana to mała próba, bez przedziałów ufności. Stała
kolejność, pamięć podręczna i rozgrzewanie procesora mogą wpływać na czasy.
Status limitu nie oznacza nierozwiązywalności. Porównania długości i energii
wykonuj dla par z poprawnymi rozwiązaniami w obu trybach; raportuj osobno
odsetek sukcesów. Wyniki odnoszą się do aktualnej kampanii i uproszczonego
modelu fizycznego, a nie do wszystkich plansz Sokobana ani rzeczywistej energii
robota. Benchmark nie zmienia algorytmu, aby uzyskać korzystniejszy wynik.

## Zapisany pomiar roboczy — 2026-11-12

Wersja silnika została sprawdzona poleceniem `--version`:
`4.7.2.stable.official.ed1daf0bf`. Uruchomiono kolejno komendy szybkiego testu
i pełnej kampanii podane powyżej, z domyślnymi trzema powtórzeniami i limitami.
Użyty program: `C:\Users\alicj\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`.
Pełne uruchomienie dodatkowo miało `--log-file results/full_run.log`;
log zachowano jako pomoc diagnostyczną, CSV pozostają źródłem danych.

- `results/quick_raw.csv`, `results/quick_summary.csv`: 18/18 sukcesów i poprawnych odtworzeń.
- `results/benchmark_raw.csv`, `results/benchmark_summary.csv`: 72 próby, 70 sukcesów,
  70 poprawnych odtworzeń, 2 × `time_limit`, brak błędnych planów. Kod wyjścia 0.
- STEPS: 34/36 sukcesów; ENERGY: 36/36. Na poziomach 1–11 wszystkie powtórzenia
  znalazły rozwiązanie w obu trybach.
- Poziom 12, STEPS: kolejno `time_limit`, `time_limit`, `solved`; czasy
  30000.264, 30000.229, 8531.787 ms. Podsumowanie jawnie zachowuje rozbieżność
  statusów, planów i liczników. ENERGY: trzy sukcesy, mediana 10517.2 ms.

| Poziom | Ruchy STEPS / ENERGY | Energia STEPS / ENERGY [J] | Obserwacja |
| --- | --- | --- | --- |
| 6 | 34 / 36 | 6481.9575 / 6364.2375 | ENERGY oszczędza 117.72 J (1.816%), dodaje 2 akcje |
| 10 | 31 / 31 | 4167.0345 / 4080.7065 | ENERGY oszczędza 86.328 J (2.072%) przy równej długości |
| 12 | 52 / 55 | 7401.5775 / 7340.5695 | STEPS ma tylko 1 sukces z 3 prób; to porównanie znalezionych planów |

Na pozostałych poziomach oba tryby dały takie same długości i energie.
ENERGY rozwinął więcej stanów na każdym poziomie 1–11. Nie należy z tych danych
wnioskować, że ENERGY zawsze działa szybciej lub zawsze wolniej: na poziomie 11
jego czasy wyniosły około 6.0, 20.8 i 21.3 s przy identycznych licznikach stanów,
a na poziomie 12 zmieniła się osiągalność limitu czasu. Przyczyny wahań nie
ustalono. Nie uruchamiano testów fizyki ani integracji równolegle z pomiarem
kampanii. Danych nie zastąpiono korzystniejszym ponownym pomiarem.

Weryfikacja kodu: `benchmark_test.gd` — 96 sprawdzeń, `physics_test.gd` — 64,
`game_integration_test.gd` — 77; wszystkie zakończyły się bez błędów. Test
integracji obejmuje obsługę WASD/strzałek, R, blokady ruchu, pchanie, energię,
animacje i odtwarzanie AI w trybie headless. Osobne próby CLI potwierdziły
`state_limit` dla jednej ekspansji i `time_limit` dla 1 ms.
Kontrolowane wstrzyknięcie błędu walidacji w tymczasowym skrypcie testowym
potwierdziło oznaczenie `replay_valid=false`, eksport błędu oraz kod wyjścia 1;
niepoprawny numer poziomu zwrócił kod 2.

Początkowo sandbox blokował zapis testów do `user://`, powodując niepowodzenie
testu trwałości postępów i testu CSV. Po uruchomieniu testów z uprawnieniem do
ich tymczasowych plików przeszły poprawnie. Benchmark zapisywał CSV w repozytorium
i tego dostępu nie potrzebował. Silnik w sandboxie wypisywał też komunikat
o niedostępnym magazynie certyfikatów systemowych; obliczenia i eksport zakończyły
się poprawnie. Odczyt konfiguracji sprzętu przez WMI był niedostępny, więc pola
sprzętowe powyżej pozostają do uzupełnienia. Nie przeprowadzono ręcznej oceny GUI.
