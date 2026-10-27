#!/usr/bin/env python3
"""Plot evolve history CSV (fitness + win rate vs generation)."""

from __future__ import annotations

import csv
import sys
from pathlib import Path


def load_csv(path: Path) -> list[dict]:
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def stage_changes(rows: list[dict]) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    prev = ""
    for row in rows:
        stage = row.get("inferred_stage") or row.get("curriculum_stage") or ""
        gen = int(float(row.get("gen", 0)))
        if stage and stage != prev:
            out.append((gen, stage))
            prev = stage
    return out


def plot_matplotlib(rows: list[dict], out_png: Path, title: str) -> None:
    import matplotlib.pyplot as plt

    gens = [int(float(r["gen"])) for r in rows]
    fitness = [float(r["best_fitness"]) for r in rows]
    vs_cascade = [100.0 * float(r.get("vs_cascade") or 0) for r in rows]
    champ_wr = [100.0 * float(r.get("champ_cum_wr") or 0) for r in rows]
    has_wr = any(w > 0 for w in champ_wr)

    fig, ax1 = plt.subplots(figsize=(11, 5.5))
    ax1.plot(gens, fitness, color="#2563eb", linewidth=1.6, label="best fitness")
    ax1.set_xlabel("generation")
    ax1.set_ylabel("best fitness", color="#2563eb")
    ax1.tick_params(axis="y", labelcolor="#2563eb")
    ax1.grid(True, alpha=0.25)

    ax2 = ax1.twinx()
    ax2.plot(gens, vs_cascade, color="#16a34a", linewidth=1.2, alpha=0.85, label="arena vs stage %")
    if has_wr:
        ax2.plot(
            gens,
            champ_wr,
            color="#ea580c",
            linewidth=1.0,
            alpha=0.8,
            linestyle="--",
            label="champ cum WR %",
        )
    ax2.set_ylabel("win rate %", color="#16a34a")
    ax2.tick_params(axis="y", labelcolor="#16a34a")
    ax2.set_ylim(0, 105)

    for gen, stage in stage_changes(rows):
        ax1.axvline(gen, color="#94a3b8", linewidth=0.6, alpha=0.5)
        ax1.text(gen, max(fitness) * 0.98, stage, rotation=90, va="top", fontsize=7, color="#64748b")

    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc="upper left", fontsize=8)
    ax1.set_title(title)
    fig.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=144)
    plt.close(fig)


def plot_svg(rows: list[dict], out_svg: Path, title: str) -> None:
    gens = [int(float(r["gen"])) for r in rows]
    fitness = [float(r["best_fitness"]) for r in rows]
    vs_cascade = [100.0 * float(r.get("vs_cascade") or 0) for r in rows]
    if not gens:
        return
    w, h = 900, 420
    pad = 50
    gx0, gx1 = min(gens), max(gens)
    fy0 = min(fitness + [0.0])
    fy1 = max(fitness + [1.0])
    wy0, wy1 = 0.0, 100.0

    def x(g: int) -> float:
        if gx1 == gx0:
            return pad
        return pad + (g - gx0) / (gx1 - gx0) * (w - 2 * pad)

    def yf(v: float) -> float:
        if fy1 == fy0:
            return h - pad
        return h - pad - (v - fy0) / (fy1 - fy0) * (h - 2 * pad)

    def yw(v: float) -> float:
        return h - pad - (v - wy0) / (wy1 - wy0) * (h - 2 * pad)

    def poly(xs: list[float], ys: list[float]) -> str:
        return " ".join(f"{a},{b}" for a, b in zip(xs, ys))

    fit_pts = poly([x(g) for g in gens], [yf(v) for v in fitness])
    wr_pts = poly([x(g) for g in gens], [yw(v) for v in vs_cascade])
    out_svg.parent.mkdir(parents=True, exist_ok=True)
    out_svg.write_text(
        f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="100%" height="100%" fill="#faf7f0"/>
  <text x="{pad}" y="24" font-size="14" fill="#334155">{title}</text>
  <polyline fill="none" stroke="#2563eb" stroke-width="2" points="{fit_pts}"/>
  <polyline fill="none" stroke="#16a34a" stroke-width="1.5" points="{wr_pts}"/>
  <text x="{pad}" y="{h - 12}" font-size="11" fill="#64748b">gen {gx0}-{gx1}</text>
</svg>
""",
        encoding="utf-8",
    )


def main() -> int:
    if len(sys.argv) < 4:
        print("Usage: plot_evolve_history.py RUN_DIR CSV_PATH OUT_PNG [LAST_N_GENS]", file=sys.stderr)
        return 2
    run_dir = Path(sys.argv[1])
    csv_path = Path(sys.argv[2])
    out_png = Path(sys.argv[3])
    rows = load_csv(csv_path)
    if not rows:
        print("empty csv", file=sys.stderr)
        return 1
    title = f"{run_dir.name}: fitness & win rate"
    try:
        plot_matplotlib(rows, out_png, title)
        print(out_png)
        return 0
    except ImportError:
        out_svg = out_png.with_suffix(".svg")
        plot_svg(rows, out_svg, title)
        print(out_svg)
        print("matplotlib not installed; wrote SVG fallback", file=sys.stderr)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
