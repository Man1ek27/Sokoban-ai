# Sokoban AI — sprawozdanie i odtwarzanie benchmarku

Do Overleafa wgraj `main.tex`, `benchmark_tables.tex` i katalog `figures/`. Ustaw `main.tex` jako dokument główny i wybierz pdfLaTeX. Źródło obsługuje także XeLaTeX.

## Powtórzenie pomiarów

Z katalogu głównego projektu, w Godot 4.7.2:

~~~text
godot --headless --editor --path . --import
godot --headless --path . --script res://sprawozdanie/benchmark.gd
~~~

Pierwsza komenda rejestruje klasy projektu na nowym komputerze. Druga nadpisuje `benchmark_raw.csv` i wykonuje kolejno trzy powtórzenia dla 12 plansz, trzech heurystyk i dwóch trybów kosztu. W przypadku publikacji nowego pomiaru zachowaj kopię poprzedniego pliku CSV. Wyniki czasowe zależą od sprzętu i obciążenia.

Do agregacji użyj Pythona 3 z Pillow:

~~~text
python sprawozdanie/aggregate_benchmark.py
~~~

Skrypt sprawdza kompletność prób i zgodność kosztów oraz odtworzeń. Aktualizuje `benchmark_summary.csv`, tabele LaTeX i oba wykresy. Po nowym pomiarze sprawdź opis warunków i interpretację w `main.tex`, a następnie ponownie skompiluj PDF.
