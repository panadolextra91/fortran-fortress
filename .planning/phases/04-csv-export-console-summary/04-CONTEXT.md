# Phase 4: CSV Export & Console Summary - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

The **terminal deliverable**: a full `fpm run` that loads the grid, sweeps the existing
physics across the 4 diurnal timesteps and 3 scenarios, **writes a deterministic CSV**
(one row per occupied cell × timestep × scenario) for external plotting, and prints a
**human-facing console summary** (hottest/coolest cell, city-average feels-like, and the
urban–rural gap, per timestep). Covers **OUT-01** (CSV export) and **OUT-02** (console
summary).

This phase adds **only output surfacing** — it does **NOT** change the physics, diurnal,
or scenario engine locked in Phases 2–3. It reuses the feels-like values and the
`summary_mod` gap/average reductions already produced by the driver (Phase 3 D-12 kept
them reachable). It ends when one `fpm run` produces a clean, plottable `results.csv` plus
a readable terminal summary, with the day-cycle/scenario story legible in both.

</domain>

<decisions>
## Implementation Decisions

### CSV Schema & Semantics (OUT-01)
- **D-01:** **One row per occupied cell × scenario × timestep.** 14 districts × 3 scenarios
  (baseline, add_trees, more_concrete) × 4 timesteps = **168 data rows + 1 header**. Empty
  grid cells are **excluded** — the `(i,j)` columns let a plotter place each district on the
  8×10 raster and leave the gaps. (Full-grid raster incl. empty cells is deferred — see
  Deferred.)
- **D-02:** **Deterministic, locale-independent CSV.** A header row, `.` decimal separator
  (never locale `,`), fixed column order, fixed iteration order (scenario → timestep → i →
  j) so the file is byte-reproducible across runs. Parses cleanly in Excel / Python / gnuplot.
- **D-03:** **"Air temp" is realized as TWO columns — `t_air` AND `base_t`** *(user decision)*.
  The CSV carries the per-cell **loaded** `t_air` (the input air temperature, finally given a
  consumer — resolves review **WR-01** and the STATE Phase-4 optics note) **and** the uniform
  diurnal **`base_t`** the model actually used at that timestep. Showing both makes the
  feels-like derivation transparent and avoids the "feels < air_temp" confusion (the reader
  sees feels-like is anchored to `base_t`, not `t_air`). **Do NOT** wire `t_air` into the
  feels computation — that would double-count the UHI effect the model isolates ("same
  baseline weather", Phase 3 D-02).
- **D-04:** **Column set:** `i, j, name, time_label, scenario, t_air, base_t, feels_c,
  uhi_offset_c`. This is a superset of OUT-01's list (grid indices, time label, scenario
  label, air temp→`t_air`+`base_t`, feels-like, UHI offset); the district `name` is included
  for readable plots. `uhi_offset_c` = the **applied** offset at that timestep
  (`m(t)·ΔT_UHI`, the value that actually moved feels-like), so a reader can see why the gap
  grows toward pre-dawn. (Raw unit-offset vs applied is a small planner choice — applied is
  recommended; a second raw column is acceptable if trivial.)

### CSV Output File (OUT-01)
- **D-05:** **Fixed `results.csv` in the project root, overwritten each run** *(user
  decision)*. Deterministic, plot-friendly, no date handling; re-plotting after tuning
  `coeffs.nml` is one `fpm run`. Written with plain formatted `write` statements — **no CSV
  library** (STACK.md). Guard against `*****` field overflow (PITFALLS **A9**) with adequate
  widths; force `.` decimals (**A10**). A configurable `output_path` namelist knob is
  **deferred** — v1 keeps OUT-01 simple.

### Console Summary (OUT-02)
- **D-06:** **Per-timestep aligned table for the baseline, plus a scenario-delta recap**
  *(user decision)*. For the **baseline** scenario, one table whose 4 rows (morning,
  afternoon, evening, pre-dawn) each show: hottest cell (name + feels °C), coolest cell
  (name + feels °C), city-average feels-like, and the urban–rural gap (reusing `summary_mod`
  D-09). Then a short **recap block**: city-average Δ for `add_trees` and `more_concrete` per
  timestep (the Phase-3 numbers, now in a clean section). This **replaces** the minimal
  Phase-3 console lines. (Keeping/removing the ASCII grid-layout print is planner's call.)
- **D-07:** **Hottest/coolest via `maxloc`/`minloc` over occupied cells** — new reductions in
  `summary_mod` alongside the existing `urban_rural_gap`/`city_average`. Report the district
  **`name`** + feels value, per timestep, baseline scenario.
- **D-08:** **Console reports feels-like only — it does NOT print per-cell `t_air` next to
  feels** (the source of the Phase-2 "FEELS < T" optics confusion). The `t_air`/`base_t`
  relationship lives in the CSV (D-03), shown side by side. This resolves the STATE Phase-4
  optics blocker.

### Pipeline (Success Criterion 4)
- **D-09:** **End-to-end from a single `fpm run`:** load (coeffs + grid) → physics (feels) →
  diurnal (4 timesteps) → scenarios (3) → CSV write + console summary. The driver must
  **retain feels-like across all scenario × timestep × cell** to emit the CSV — either stream
  each row as it is computed inside the existing loop, or collect into an array, then write.
  Phase 3 D-12 already kept feels reachable; this phase wires the output without touching the
  kernels.

### Claude's Discretion
- Module placement of the CSV writer (extend `io_mod` with `write_results_csv`, or a new
  `output_mod`) and the new reductions (extend `summary_mod`); exact header strings, field
  widths, and format specifiers; whether to keep the ASCII grid print; stream-rows vs collect
  into a 4D array; exact table alignment; how the `uhi_offset_c` value is obtained (recompute
  via the public `uhi_offset` × `m(t)`, or have the feels path return it). Kernels stay
  `elemental pure`; formatted `write` only; `_wp` on every literal; no integer division; guard
  format widths (A9).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 4: CSV Export & Console Summary" — goal, 4 success criteria
  (OUT-01 deterministic CSV schema; clean parse; OUT-02 console summary; single-`fpm run`
  pipeline).
- `.planning/REQUIREMENTS.md` — **OUT-01**, **OUT-02** (the two delivered here), incl. the
  exact OUT-01 column list and OUT-02 contents.
- `.planning/PROJECT.md` — Core Value (believable spatial pattern), Constraints (CSV output +
  brief console summary; plot in external tools; no built-in graphics).

### Output mechanics & pitfalls
- `.planning/research/PITFALLS.md` §**A9** (`*****` formatted-write field overflow — size
  widths), §**A10** (locale decimal separator — force `.` not `,`).
- `.planning/research/STACK.md` — CSV writing is plain formatted `write`; **no library**;
  strict dev flags via `fpm test --flag "..."` (fpm 0.13.0 rejects `[profiles.*.gfortran]`).
- `.planning/research/ARCHITECTURE.md` — module build order placing output above the physics
  kernels; pure-kernel design.

### Engine contracts consumed (locked, do not modify)
- `.planning/phases/03-day-night-cycle-scenario-comparison/03-CONTEXT.md` — **D-02** (base(t)
  uniform → cancels in gap, offset carries the gap), **D-09** (gap = mean-urban − mean-rural,
  reusable here), **D-12** (feels reachable for Phase-4 output).
- `.planning/phases/03-day-night-cycle-scenario-comparison/03-REVIEW.md` — **WR-01** rationale
  (why `t_air` is reference-only and must NOT drive feels) behind D-03/D-08.
- `.planning/phases/02-feels-like-physics-heat-index-uhi-offset/02-CONTEXT.md` — D-09 floor
  (`feels = max(HeatIndex, t_adj)`), the per-cell `rh`/`t_air` data contract.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/main.f90` — the driver **already** loops `scenario → timestep → (i,j)` and computes
  `feels_current(i,j)` per scenario/timestep; it prints the minimal Phase-3 console lines.
  Phase 4 retains feels across all combinations for the CSV and swaps the minimal print for
  the OUT-02 summary table.
- `src/summary.f90` — `urban_rural_gap` and `city_average` (occupied-mask means) are reused
  directly for OUT-02; **add** `hottest`/`coolest` (`maxloc`/`minloc` over the occupied mask)
  returning cell index + value.
- `src/io.f90` — `read_coeffs_nml` / `read_grid_csv` show the formatted-IO + `newunit` open
  pattern; the new `write_results_csv` follows it (open for write, header line, formatted row
  loop, close). `int2str`/`make_msg` patterns available.
- `src/grid.f90` — `cell` carries `name`, `i`, `j`, `t_air` (**now consumed** in the CSV),
  `rh`, `building`, `tree`, `is_urban`, `occupied`; `coeffs_t` carries `base_*`, `m_*`, deltas.
- `src/diurnal.f90` — `diurnal_base(c,it)` → `base_t` column; `time_label(it)` → `time_label`
  column; `diurnal_m(c,it)` → factor for the applied `uhi_offset_c`.
- `src/uhi.f90` — `uhi_offset(...)` is **public**, so the CSV `uhi_offset_c = m(t)*uhi_offset`
  can be recomputed per row without changing the feels kernel.

### Established Patterns
- `private` modules with explicit `public`, one module per file, `use ..., only:`; kernels
  `elemental pure`; load-time fail-loud validation; **rank/sign over absolute °C** in tests
  (Phase 2 D-11 / Phase 3 D-10). New output code uses formatted `write`, no global state.
- Tests use **test-drive**; an output test can assert CSV header/row-count/`.`-decimals and
  that `results.csv` is produced by a run (golden-ish, but assert structure not exact °C).

### Integration Points
- The CSV writer + summary table consume the **retained feels values** + `grid_t` + `coeffs_t`;
  no changes to `feels_mod` / `uhi_mod` / `diurnal_mod` / `scenario_mod` (locked Phases 2–3).
- Deterministic row order (scenario, timestep, i, j) makes `results.csv` byte-reproducible.

</code_context>

<specifics>
## Specific Ideas

- The teaching payoff (carried from Phase 3) is the **shape**: mid-afternoon is absolute-
  hottest yet has the *smallest* urban–rural gap; pre-dawn is cooler yet has the *largest*
  gap. The CSV must let a learner plot feels-like per cell across the 4 timesteps and **see**
  this emerge — and carrying both `t_air` and `base_t` makes the "same baseline weather"
  experiment legible.
- `results.csv` overwritten each run so the tune-`coeffs.nml` → `fpm run` → re-plot loop is a
  single command.
- The console summary should read like a tiny report a human scans in the terminal — names +
  °C, aligned — not a debug dump.

</specifics>

<deferred>
## Deferred Ideas

- **Configurable CSV output path/filename** via a `coeffs.nml` `output_path` knob — v2 (D-05
  fixes `results.csv`).
- **Timestamped CSV history** (`results_<date>.csv`) — v2.
- **Full-grid raster rows** (incl. empty cells, ~960 rows) for plotters that want a complete
  8×10 matrix — v2; v1 is occupied-only with `(i,j)` (D-01).
- **Full all-scenario × all-timestep console table** (12 combinations) — v1 console is the
  baseline table + scenario-delta recap (D-06).
- **The plotting itself** (gnuplot / Python / Excel) — out of the Fortran build; the CSV is
  the contract (PROJECT.md).
- **REFN-\*** (humidex toggle, cosine diurnal curve, more districts, seasonal baselines) — v2.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 4-CSV Export & Console Summary*
*Context gathered: 2026-06-29*
