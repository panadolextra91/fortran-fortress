# Phase 4: CSV Export & Console Summary - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 4-CSV Export & Console Summary
**Areas discussed:** Air-temp column & t_air, CSV file path & overwrite, CSV row scope, Console summary format

---

## Air-temp column & t_air

| Option | Description | Selected |
|--------|-------------|----------|
| Both: t_air + base_t | CSV carries per-cell loaded `t_air` (finally consumed) AND the uniform `base_t` the model used; transparent, avoids "feels < air_temp" confusion | ✓ |
| Per-cell t_air only | Single "air_temp" = loaded t_air (literal OUT-01); feels<t_air looks odd in a plot | |
| Uniform base_t only | "air_temp" = base(t) used; internally consistent but drops per-cell t_air (dead column stays dead) | |

**User's choice:** Both columns (t_air + base_t)
**Notes:** Resolves review WR-01 (t_air loaded but unused) and the STATE Phase-4 optics blocker by giving `t_air` a real consumer in the CSV. `t_air` must still NOT drive the feels computation (would double-count UHI). → CONTEXT D-03.

---

## CSV file path & overwrite

| Option | Description | Selected |
|--------|-------------|----------|
| results.csv, overwrite | Fixed `results.csv` in project root, overwritten each `fpm run`; deterministic, plot-friendly | ✓ |
| Configurable path in coeffs.nml | Add `output_path` namelist var (config-without-recompile ethos) but adds a knob | |
| Timestamped files | `results_<date>.csv` keeps history but clutters + needs date handling | |

**User's choice:** Fixed `results.csv`, overwrite
**Notes:** Keeps the tune-`coeffs.nml` → `fpm run` → re-plot loop one command. Configurable path deferred to v2. → CONTEXT D-05.

---

## CSV row scope

| Option | Description | Selected |
|--------|-------------|----------|
| Occupied × 3 scenarios × 4 timesteps | 14 districts × 3 × 4 = 168 rows; clean, only real data; (i,j) lets a plotter place cells on the raster | ✓ |
| All grid cells incl. empty | 80 × 12 = 960 rows; full 8×10 raster but many empty rows | |
| Baseline only (occupied) | 14 × 4 = 56 rows; simplest but drops scenario comparison from CSV | |

**User's choice:** Occupied × 3 scenarios × 4 timesteps (168 rows)
**Notes:** Full-grid raster deferred to v2. → CONTEXT D-01.

---

## Console summary format

| Option | Description | Selected |
|--------|-------------|----------|
| Per-timestep table for baseline + delta recap | Baseline: aligned table per timestep (hottest/coolest name+°C, city-avg, gap); plus city-avg Δ recap per scenario; replaces Phase-3 minimal lines | ✓ |
| Full all-scenario × timestep table | hottest/coolest/avg/gap for all 12 combinations; thorough but verbose | |
| Compact lines (extend Phase 3) | Keep minimal gap lines + add hottest/coolest/avg; least restructuring | |

**User's choice:** Per-timestep baseline table + scenario-delta recap
**Notes:** Console reports feels-like only (no per-cell `t_air` next to feels — that was the Phase-2 "FEELS < T" optics issue); the t_air/base_t relationship lives in the CSV. → CONTEXT D-06, D-07, D-08.

---

## Claude's Discretion

- Module placement of the CSV writer (`io_mod` vs new `output_mod`) and the new reductions (extend `summary_mod`).
- Exact header strings, field widths, format specifiers; table alignment.
- Whether to keep the ASCII grid-layout print; stream-rows vs collect into a 4D array.
- How `uhi_offset_c` is obtained (public `uhi_offset` × `m(t)` vs feels path returning it).

## Deferred Ideas

- Configurable CSV output path/filename via `coeffs.nml` — v2.
- Timestamped CSV history — v2.
- Full-grid raster rows (incl. empty cells) — v2.
- Full all-scenario × all-timestep console table — v1 is baseline table + delta recap.
- Plotting itself (gnuplot/Python/Excel) — out of the Fortran build; CSV is the contract.
- REFN-* (humidex toggle, cosine diurnal, more districts, seasonal baselines) — v2.
