"""Aggregate three benchmark repetitions and regenerate the report tables and figures."""

import csv
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
LEVELS = range(1, 13)
MODES = ("steps", "energy")
HEURISTICS = ("h1", "h2", "h3")
COLORS = ("#286892", "#157f73")


def summarize(raw):
    groups = {}
    for row in raw:
        key = (int(row["level"]), row["cost_mode"], row["heuristic"])
        groups.setdefault(key, []).append(row)
    expected = {(level, mode, h) for level in LEVELS for mode in MODES for h in HEURISTICS}
    if groups.keys() != expected or len({row["code_sha256"] for row in raw}) != 1:
        raise ValueError("Benchmark musi obejmować pełną kampanię i jeden stan kodu.")

    summary = {}
    for key in sorted(groups):
        rows = groups[key]
        solved = [row for row in rows if row["status"] == "solved"]
        if len(rows) != 3 or {row["run_id"] for row in rows} != {"1", "2", "3"}:
            raise ValueError(f"Niekompletne powtórzenia dla {key}")
        if any(row["replay_ok"] != "true" for row in solved):
            raise ValueError(f"Błędne odtworzenie planu dla {key}")
        times = [float(row["elapsed_ms"]) for row in solved]
        representative = solved[0] if solved else {}
        metrics = ("moves", "pushes", "energy_j", "expanded_states", "discovered_states")
        for metric in metrics:
            if len({row[metric] for row in solved}) > 1:
                raise ValueError(f"Różne wartości {metric} pomiędzy powtórzeniami dla {key}")
        summary[key] = {
            "level": key[0], "level_name": rows[0]["level_name"], "cost_mode": key[1],
            "heuristic": key[2], "runs": len(rows), "solved": len(solved),
            "time_limits": sum(row["status"] == "time_limit" for row in rows),
            "state_limits": sum(row["status"] == "state_limit" for row in rows),
            "elapsed_median_ms": round(median(times), 3) if times else "",
            "elapsed_min_ms": min(times, default=""),
            "elapsed_max_ms": max(times, default=""),
            **{metric: representative.get(metric, "") for metric in metrics},
        }

    for level in LEVELS:
        for mode in MODES:
            metric = "moves" if mode == "steps" else "energy_j"
            costs = [float(summary[level, mode, h][metric]) for h in HEURISTICS
                     if summary[level, mode, h]["solved"]]
            if costs and max(costs) - min(costs) > 1e-6:
                raise ValueError(f"Niezgodne koszty celu dla poziomu {level} w {mode}.")
    return summary


def tex_number(value, places=0):
    return f"{float(value):,.{places}f}".replace(",", r"\,").replace(".", ",")


def write_tables(summary):
    if any(not row["solved"] for row in summary.values()):
        raise ValueError("Tabele i wykresy wymagają co najmniej jednej udanej próby w każdej konfiguracji.")
    total_rows = []
    last_rows = []
    energy_rows = []
    for mode in MODES:
        for h in HEURISTICS:
            rows = [summary[level, mode, h] for level in LEVELS]
            total_rows.append([
                mode.upper(), f"$h_{h[-1]}$", f"{sum(r['solved'] for r in rows)}/36",
                tex_number(sum(int(r["expanded_states"]) for r in rows)),
                tex_number(sum(int(r["discovered_states"]) for r in rows)),
                tex_number(sum(r["elapsed_median_ms"] for r in rows) / 1000, 2),
            ])
            last = rows[-1]
            last_rows.append([
                mode.upper(), f"$h_{h[-1]}$", tex_number(last["expanded_states"]),
                tex_number(last["discovered_states"]), tex_number(last["elapsed_median_ms"] / 1000, 2),
            ])

    savings = []
    for level in LEVELS:
        steps, energy = (summary[level, mode, "h1"] for mode in MODES)
        before, after = float(steps["energy_j"]), float(energy["energy_j"])
        saved = before - after
        savings.append(100 * saved / before if before else 0)
        if saved > 1e-6:
            energy_rows.append([
                f"{level}. {steps['level_name']}", f"{steps['moves']}/{energy['moves']}",
                tex_number(before, 2), tex_number(after, 2),
                tex_number(saved, 2), tex_number(savings[-1], 2),
            ])

    with (ROOT / "benchmark_tables.tex").open("w", encoding="utf-8", newline="\n") as output:
        output.write("% Wygenerowano przez aggregate_benchmark.py na podstawie benchmark_raw.csv.\n")
        for command, rows in (("HeuristicSummaryRows", total_rows), ("LastLevelRows", last_rows),
                              ("EnergyTradeoffRows", energy_rows)):
            output.write(r"\newcommand{" + "\\" + command + "}{%\n")
            for row in rows:
                output.write(" & ".join(row) + r" \\" + "\n")
            output.write("}\n")
    return savings


def font(size, bold=False):
    candidates = ("arialbd.ttf", "DejaVuSans-Bold.ttf") if bold else ("arial.ttf", "DejaVuSans.ttf")
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def plot_bars(filename, panels, limits, ticks, ylabel, labels):
    width, height = 1400, 580 if len(panels) == 2 else 435
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    title, normal, small = font(29, True), font(24), font(21)
    left, right = 108, width - 35
    step = (right - left) / len(LEVELS)
    minimum, maximum = limits
    draw.text((left, 15), ylabel, font=normal, fill="#222b36")
    for panel, (mode, series) in enumerate(panels):
        top = 78 + panel * 242
        bottom = top + (155 if len(panels) == 2 else 260)

        def y(value):
            return bottom - (value - minimum) / (maximum - minimum) * (bottom - top)

        if mode:
            draw.text((left, top - 31), mode, font=title, fill="#222b36")
        for tick in ticks:
            axis_y = y(tick)
            draw.line((left, axis_y, right, axis_y), fill="#8d9aa6" if tick == 0 else "#e4e9ef", width=2)
            draw.text((left - 14, axis_y), f"{tick:g}".replace(".", ","),
                      font=small, anchor="rm", fill="#334255")
        bar_width = step * 0.58 / len(series)
        for series_index, values in enumerate(series):
            for index, value in enumerate(values):
                center = left + (index + 0.5) * step + (series_index - (len(series) - 1) / 2) * bar_width
                if abs(value) > 1e-6:
                    draw.rectangle((center - bar_width * 0.46, min(y(0), y(value)),
                                    center + bar_width * 0.46, max(y(0), y(value))), fill=COLORS[series_index])
                    if len(series) == 1:
                        draw.text((center, y(value) - 9), f"{value:.2f}".replace(".", ","),
                                  font=small, anchor="mb", fill="#222b36")
        for index in LEVELS:
            draw.text((left + (index - 0.5) * step, bottom + 12), str(index),
                      font=small, anchor="mt", fill="#334255")
    draw.text((right, height - 29), "Poziom kampanii", font=small, anchor="rm", fill="#334255")
    for index, label in enumerate(labels):
        x = right - 210 + index * 105
        draw.rectangle((x, 18, x + 24, 37), fill=COLORS[index])
        draw.text((x + 31, 27), label, font=normal, anchor="lm", fill="#222b36")
    image.save(ROOT / "figures" / filename)


def main():
    with (ROOT / "benchmark_raw.csv").open(encoding="utf-8-sig", newline="") as source:
        summary = summarize(list(csv.DictReader(source)))
    rows = list(summary.values())
    with (ROOT / "benchmark_summary.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    savings = write_tables(summary)
    changes = []
    for mode in MODES:
        baseline = [int(summary[level, mode, "h1"]["expanded_states"]) for level in LEVELS]
        series = [[100 * (1 - int(summary[level, mode, h]["expanded_states"]) / base)
                   for level, base in zip(LEVELS, baseline)] for h in ("h2", "h3")]
        changes.append((mode.upper(), series))
    plot_bars("rozwiniete_stany.png", changes, (-10, 90), (0, 20, 40, 60, 80),
              "Redukcja rozwinięć względem h1 [%]", ("h2", "h3"))
    plot_bars("oszczednosc_energii.png", [("", [savings])], (0, 2.5), (0, 0.5, 1, 1.5, 2, 2.5),
              "Oszczędność energii względem STEPS [%]", ())


if __name__ == "__main__":
    main()
