# Sokoban AI

Projekt gry Sokoban 2D w Godot Engine 4. Aktualna wersja zawiera prostą planszę testową, sterowanie graczem, pchanie skrzyni oraz podstawowy model fizyczny przygotowany pod przyszłą integrację z algorytmem A*.

## Co jest już zrobione

### Plansza i rozgrywka

- Dodano scenę startową gry w pliku `main.tscn`.
- Plansza jest rysowana programowo w 2D, więc nie wymaga dodatkowych grafik.
- Dodano ściany, podłoże, cel, gracza i skrzynię.
- Gracz może poruszać się po planszy za pomocą klawiszy `WASD` lub strzałek.
- Skrzynię można pchać, jeżeli pole za nią jest wolne.
- Ruch przez ścianę lub zablokowanie skrzyni jest odrzucane.
- Klawisz `R` resetuje poziom.
- Na ekranie wyświetlane są:
  - liczba wykonanych ruchów,
  - zużyta energia w dżulach,
  - maksymalna siła robota,
  - komunikat o ostatnim działaniu.

### Parser poziomów

Poziom jest przechowywany w pliku `levels/demo_level.json` i wczytywany przez `scripts/level_data.gd`.

Parser obsługuje:

- `#` — ściana,
- `.` — zwykłe podłoże,
- `G` — cel,
- `P` — pozycję gracza,
- `B` — skrzynię,
- `*` — skrzynię znajdującą się na celu,
- `I` — lód,
- `S` — piasek.

Masę skrzyni można ustawić w sekcji `boxes` pliku JSON. Maksymalna siła robota jest ustawiana przez parametr `robot_force`.

### Model fizyczny

Model fizyczny znajduje się w `scripts/physical_model.gd`. Jest niezależnym modułem, który może być używany zarówno przez warstwę gry, jak i przyszły algorytm AI.

Zaimplementowane elementy:

- masa skrzyni,
- masa robota wynosząca `20 kg`,
- maksymalna siła robota,
- tarcie statyczne podłoża,
- tarcie kinetyczne podłoża,
- sprawdzanie, czy robot ma wystarczającą siłę do ruszenia skrzyni,
- obliczanie pracy potrzebnej do wykonania ruchu,
- naliczanie kosztu energetycznego w dżulach,
- poślizg skrzyni na lodzie,
- zatrzymywanie skrzyni po wytraceniu energii lub napotkaniu przeszkody.

Parametry podłoża:

| Podłoże | Tarcie statyczne | Tarcie kinetyczne |
| --- | ---: | ---: |
| Drewno / zwykłe pole | 0.35 | 0.25 |
| Lód | 0.05 | 0.03 |
| Piasek | 0.75 | 0.65 |

## Uruchomienie

1. Otwórz folder projektu w Godot Engine 4.
2. Otwórz projekt z pliku `project.godot`.
3. Uruchom projekt przyciskiem **Play** albo klawiszem `F6`/`F5`.
4. Scena startowa jest ustawiona na `main.tscn`.

Jeżeli Godot nie uruchamia sceny automatycznie, otwórz ręcznie plik `main.tscn` i uruchom bieżącą scenę.

## Sterowanie

| Klawisz | Działanie |
| --- | --- |
| `W`, `A`, `S`, `D` | Ruch gracza |
| Strzałki | Ruch gracza |
| `R` | Reset planszy |

## Struktura dodanych plików

```text
main.tscn
project.godot
README.md
levels/
  demo_level.json
scripts/
  game.gd
  level_data.gd
  physical_model.gd
```

## Przykładowa plansza

Aktualna plansza testowa znajduje się w `levels/demo_level.json`. Zawiera jedną skrzynię, jeden cel oraz pola lodu i piasku, dzięki czemu można sprawdzić różnicę w zachowaniu i koszcie ruchu.

## Dalszy rozwój

Kolejne elementy, które można dodać do projektu:

- algorytm A* wykorzystujący koszt energetyczny z `PhysicalModel`,
- wykrywanie deadlocków,
- więcej skrzyń o różnych masach,
- wybór poziomu z interfejsu,
- animowanie ruchu gracza i skrzyń,
- panel parametrów fizycznych,
- uruchamianie i zatrzymywanie autonomicznego agenta AI,
- prezentacja statystyk planowania.
