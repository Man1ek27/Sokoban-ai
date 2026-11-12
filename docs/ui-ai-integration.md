# HUD i podgląd AI

## Wygląd i układ

Bazowa rozdzielczość wynosi 1200 × 800. Plansza i legenda terenu są po lewej, panel sterowania po prawej. Pełny wynik wyszukiwania mieści się bez przewijania przy bazowym rozmiarze; `ScrollContainer` pozostaje zabezpieczeniem dla większych treści. Plansza jest wyśrodkowana w obszarze planszy; kafelki mają 56 px, a poziomy większe niż ten obszar są proporcjonalnie zmniejszane (`draw_set_transform`). Legenda pokazuje tylko elementy obecne na poziomie i przechodzi do dwóch rzędów, gdy się nie mieści.

Wspólny motyw kontrolek znajduje się w `ui/game_theme.tres`. Plansza, robot, skrzynie i wzory terenu nadal są rysowane proceduralnie w `game.gd`, bez tekstur i dodatkowych zależności. Cele mają turkusowe oznaczenia, a skrzynia stojąca na celu — turkusową obwódkę. Masa skrzyni jest wyśrodkowana na osobnej etykiecie.

## Parametry i cykl życia

- Heurystyka i kryterium kosztu są niezależnymi ustawieniami. Obecnie dostępna jest wyłącznie h1. Zmiana ustawienia usuwa poprzedni wynik.
- Fmax jest podawane w N, z krokiem 0,1 N. Zmiana aktualizuje jednocześnie `level.robot_force` i `physics.robot_force`, usuwa plan i wynik wyszukiwania. Zachowuje bieżącą pozycję obiektów, liczbę ruchów i energię już wykonanych ruchów.
- Reset (R, przycisk resetu, ponowna gra) i wybór poziomu ponownie odczytują JSON: przywracają początkowy stan, Fmax i zerują liczniki. Nie zapisujemy zmian do JSON. Wybór heurystyki i kryterium kosztu pozostaje zachowany.
- Parametry i przycisk rozwiązywania są blokowane podczas planowania, odtwarzania oraz animacji. Reset i wybór poziomu pozostają dostępne podczas animacji/odtwarzania.
- Zatrzymanie AI usuwa pozostały plan i podgląd. Bieżąca animacja kończy się, ponieważ ruch został już zastosowany do stanu logicznego. Jeśli to ostatnie pchnięcie na cel, nadal następuje zwycięstwo. Potem można grać ręcznie lub ponownie planować z bieżącego stanu.
- Reset zabija aktywny tween. Licznik generacji odrzuca planowanie oczekujące na następną klatkę.

## Podgląd

`game.gd::_build_ai_preview()` symuluje plan na kopii `BoardState` przez ten sam `PhysicalModel.move()`, którego używają gra i solver. Każdy wpis zawiera początek/koniec ruchu robota i pełną ścieżkę skrzyni (pozycja początkowa plus `result["path"]`). Podgląd nie modyfikuje stanu gry.

Niebieskie ciągłe strzałki przedstawiają robota, fioletowe przerywane strzałki — skrzynie. Trasy są rysowane na kafelkach przed celami, skrzyniami i robotem. Podczas odtwarzania rysowany jest tylko bieżący animowany ruch i pozostały fragment planu. Dane symulacji powstają raz na plan; kolejne klatki nie powtarzają symulacji.

Statystyki czasu, stanów, długości i energii pochodzą bezpośrednio z wyniku `solve()`. Dla nieudanego wyszukiwania długość i energia rozwiązania mają znak „—”, ponieważ zerowe pola solvera nie oznaczają rozwiązania o zerowym koszcie. Wynik wyszukiwania jest zachowany po zatrzymaniu/wykonaniu AI, a osobny komunikat opisuje stan odtwarzania.

## Podłączenie h2/h3 przez Radzia

Kontrakt `AStarSolver.solve()` pozostaje bez zmian. Czwarty argument to `Callable(state: BoardState, level: LevelData) -> float`. Heurystyka powinna zwracać skończoną nieujemną wartość, bez mutowania stanu. Jej skala musi odpowiadać STEPS albo ENERGY i uwzględniać poślizg, jeśli ma zachować gwarancję optymalności.

Proponowana forma, zgodna z obecną `manhattan_for`, to fabryki w `SokobanHeuristics`:

```gdscript
# Propozycja przyszłego interfejsu, bez implementacji na tym branchu:
static func weighted_for(level: LevelData, energy_cost: bool = false) -> Callable
static func terrain_aware_for(level: LevelData, energy_cost: bool = false) -> Callable
```

Po dostarczeniu implementacji należy dodać przypadki `GameHud.Heuristic.H2/H3` w `game.gd::_heuristic_for()` i odblokować odpowiednie pozycje w `GameHud._ready()`. Fabryki są wywoływane dla każdego nowego wyszukiwania, dzięki czemu otrzymują aktualny Fmax. Nie należy zastępować brakującej implementacji pustym `Callable`: solver potraktowałby go jako prośbę o domyślną h1. Obecny adapter odrzuca niedostępne heurystyki przed wywołaniem solvera.

Sygnał HUD ma postać `ai_solve_requested(cost_mode: int, heuristic_id: int)`. Inne sygnały integracyjne: `robot_force_changed(force: float)` i `ai_settings_changed`.

## Weryfikacja

Godot 4.7.2:

```text
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 10
godot --headless --path . --log-file ./.godot/integration-test.log --script res://tests/game_integration_test.gd
```

Test integracyjny sprawdza prawdziwe przejścia, animacje i wyniki solvera, w tym oba poziomy JSON i tryby kosztu. Dodatkowe plansze testowe powstają w pamięci. Limit czasu jest wymuszany rzeczywistym wywołaniem solvera z wolnym testowym `Callable`; nie jest wytwarzany fikcyjny słownik wyniku.

Do sprawdzenia wizualnego w edytorze:

1. Uruchomić oba poziomy; sprawdzić WASD, strzałki, ściany, pchanie i naliczanie energii.
2. Sprawdzić osobne selektory heurystyki/kosztu, blokadę h2/h3 i przewijanie HUD.
3. W „Test zwycięstwa” ustawić Fmax na 0 N; pchanie i solver powinny nie móc rozwiązać poziomu. R przywraca 300 N.
4. W „Demo fizyki” uruchomić AI, obserwować niebieską trasę robota i fioletowe odcinki poślizgu, ich skracanie oraz czytelność obiektów.
5. Zatrzymać AI podczas ruchu/pchania, potem ruszyć ręcznie. Parametry odblokowują się po zakończeniu animacji.
6. Resetować w trakcie animacji i zmienić poziom po zwycięstwie; nie powinno być pozostałych tras ani starego ekranu zwycięstwa.

Ograniczenie odziedziczone po integracji: solver działa synchronicznie na głównym wątku (limit 100000 rozwiniętych stanów / 30000 ms). Podczas samego wyszukiwania okno nie obsługuje zdarzeń; zatrzymanie dotyczy odtwarzania. Przeniesienie wyszukiwania na osobny wątek wymaga oddzielnej zmiany integracji. Test headless nie ocenia wyglądu kolorów ani ergonomii klikania.
