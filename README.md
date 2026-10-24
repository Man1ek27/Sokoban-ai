# Sokoban AI

Projekt gry Sokoban 2D w Godot Engine 4.7.2 (GDScript). Obecna wersja pozwala ręcznie grać na planszach z fizyką pchania skrzyń. Docelowo projekt ma zawierać solver A* porównujący heurystyki i uwzględniający fizykę, ale solver nie jest jeszcze zaimplementowany.

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

HUD pokazuje liczbę wykonanych ruchów, zużytą energię, maksymalną siłę robota i komunikat o ostatnim działaniu. Ruch gracza i skrzyni jest animowany; poślizg skrzyni przebiega przez kolejne pola wyznaczone przez model fizyczny. Podczas animacji i po ukończeniu poziomu kolejne ruchy są blokowane.

Po umieszczeniu wszystkich skrzyń na celach pojawia się ekran ukończenia z liczbą ruchów i energią. Można zagrać ponownie albo zamknąć komunikat. Zamknięcie komunikatu nie odblokowuje ruchu na ukończonym poziomie; można go zresetować lub wybrać inny.

## Poziomy

| Plik | Zawartość | Przeznaczenie |
| --- | --- | --- |
| `levels/demo_level.json` | Dwie skrzynie (35 i 45 kg), jeden cel, lód i piasek | Demonstracja pchania, tarcia i poślizgu. Nie spełnia warunku ukończenia, który wymaga równej liczby skrzyń i celów. |
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

`scripts/physical_model.gd` sprawdza, czy siła robota wystarcza do ruszenia skrzyni, czy pole docelowe jest wolne, oraz wyznacza końcową pozycję, trasę poślizgu i koszt energetyczny pchnięcia. Gracz nie przechodzi przez ściany ani przez zablokowane skrzynie. Koszt energii jest naliczany za udane pchnięcia; zwykły krok gracza go nie zwiększa.

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
levels/demo_level.json       demonstracja fizyki
levels/win_test.json         test zwycięstwa
addons/godot_ai/             dodatek edytora do integracji MCP
```

## Dalszy rozwój

Planowane są solver A* z kilkoma heurystykami, wykrywanie zakleszczeń geometrycznych i fizycznych, planowanie z kosztami wynikającymi z modelu fizycznego oraz odtwarzanie i wizualizacja decyzji AI. Obecna gra nie uruchamia solvera ani nie prezentuje statystyk planowania.
