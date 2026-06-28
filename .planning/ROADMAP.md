# Roadmap: Fortran Fortress — HCMC Urban Heat Island Simulator

## Overview

Build a modern-Fortran batch simulator that reads HCMC district data from an editable
file, sweeps a stack of pure physics kernels (heat index → UHI offset → diurnal cycle)
across what-if scenarios, and exports CSV plus a console summary. The journey follows the
research's acyclic module build order, consolidated into four coarse phases that each end
in a compilable, `fpm run`-able artifact: first an fpm scaffold that loads and prints the
grid, then per-cell feels-like physics with the headline urban>rural ordering, then the
day-night cycle and scenario engine carrying the night-amplified gap, and finally the CSV
exporter and terminal summary that complete the deliverable. The two make-or-break science
invariants — urban cells hotter than green/waterfront for the same baseline, and a larger
urban-rural gap at night than mid-afternoon — are pinned as explicit success criteria with
automated tests in the phases that own them.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Build Scaffold & Grid Loader** - fpm project, foundation modules, and an editable HCMC grid that loads, validates, and prints ✅ Complete (2026-06-28)
- [ ] **Phase 2: Feels-Like Physics (Heat Index + UHI Offset)** - per-cell apparent temperature with range guard and the urban>rural ordering invariant
- [ ] **Phase 3: Day-Night Cycle & Scenario Comparison** - diurnal evaluation carrying the night-amplified gap, plus immutable-baseline what-if scenarios
- [ ] **Phase 4: CSV Export & Console Summary** - deterministic CSV output and the terminal hottest/coolest/average/gap report

## Phase Details

### Phase 1: Build Scaffold & Grid Loader

**Goal**: A runnable fpm project whose foundation and data layers exist — the simulator
loads the HCMC grid from an editable data file (with model coefficients), validates it, and
prints the loaded cells. This replaces the throwaway Hello-World Makefile scaffold.
**Depends on**: Nothing (first phase)
**Requirements**: GRID-01, GRID-02, GRID-03, GRID-04
**Success Criteria** (what must be TRUE):

  1. `fpm build`, `fpm run`, and `fpm test` all run clean from a fresh checkout — fpm
     auto-resolves module compile order (no stale `.mod`, no hand-ordered build).

  2. Running the program loads a 2D grid of HCMC cells from an editable data file and echoes
     them to the terminal; editing the data file changes the output with no recompile (GRID-01).

  3. Each loaded cell carries air temperature, relative humidity, distance to river/ocean,
     building density, tree density, and an urban/rural class — all stored/converted as
     `real(real64)` so no integer-division or precision loss enters later math (GRID-02).

  4. The seed file ships realistic HCMC archetypes (District 1 core, industrial zone,
     park/green, Can Gio coast, rural fringe), and a malformed or out-of-range row is rejected
     loudly with its line number rather than silently column-shifted (GRID-03).

  5. UHI weights and diurnal multipliers live in the editable config/data file (not source)
     and are loaded at runtime, so coefficients can be tuned without recompiling (GRID-04).
**Plans**: TBD

Plans:
**Wave 1**

- [x] 01-01: Stand up the fpm project (fpm.toml, src/test layout, dev/release flag profiles, retire the Makefile scaffold)
- [x] 01-04: HCMC seed data file + scenario-coefficient config; driver stub that loads, validates, and prints the grid; config read round-trip test *(consolidated into 01-02 + 01-03 during execution)*

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02: Foundation + grid types — kinds_mod (wp=real64), constants_mod, grid_mod (type(cell)/grid_t, allocate-once)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03: io_mod reader + config loader — delimited parse with iostat/range validation; load UHI weights & diurnal multipliers

### Phase 2: Feels-Like Physics (Heat Index + UHI Offset)

**Goal**: The simulator computes a believable per-cell feels-like temperature for a single
baseline time — apparent temperature from air temp and humidity, perturbed by an additive
UHI offset — and the headline spatial ordering (dense treeless urban hotter than
green/waterfront/rural) holds and is locked by an automated test.
**Depends on**: Phase 1
**Requirements**: HEAT-01, HEAT-02, UHI-01, UHI-02
**Success Criteria** (what must be TRUE):

  1. The program computes a per-cell feels-like (apparent) temperature from air temperature
     and relative humidity for every cell in the grid (HEAT-01).

  2. The heat-index calculation guards its valid range — Steadman average below ~26.7 °C
     (80 °F), Rothfusz regression at/above — so cool/night cells never return a feels-like
     below air temperature; verified by a boundary test at the 80 °F threshold (HEAT-02).

  3. The additive UHI offset raises feels-like for higher building density / urban class and
     lowers it for higher tree density and water proximity, acting through a single documented
     temperature budget that keeps each driver's contribution to single-digit °C and waterfront
     cells cooler (UHI-01).

  4. For the same baseline weather, dense treeless urban cells rank hotter than
     green / waterfront / rural cells (monotonic ordering) — verified by an automated test (UHI-02).
**Plans**: 3 plans

Plans:
**Wave 1** *(parallel — disjoint files)*

- [ ] 02-01-PLAN.md — heat_index_mod: extend constants_mod (c_to_f/f_to_c + Rothfusz coeffs) and add the elemental pure two-branch Steadman/Rothfusz kernel; NWS reference + 80 °F boundary test (HEAT-01, HEAT-02)
- [ ] 02-02-PLAN.md — uhi_mod: elemental pure single-budget additive offset (Wprox = exp(−water_km/d0)); add tunable d0 to coeffs_t/namelist with fail-loud d0 > 0 guard; sign/monotonicity + magnitude test (UHI-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 02-03-PLAN.md — feels_mod wrapper (max(HeatIndex(t_base+ΔT, rh), t_adj)) + wire feels-like into the driver loop + synthetic-archetype dense-urban > green/waterfront/rural ordering test (HEAT-01, HEAT-02, UHI-02)

### Phase 3: Day-Night Cycle & Scenario Comparison

**Goal**: The simulator evaluates the grid across multiple times of day and across baseline
plus what-if scenarios — reproducing the signature result that the urban-rural gap is larger
at night than mid-afternoon, and quantifying how each scenario warms or cools the city
against an immutable baseline.
**Depends on**: Phase 2
**Requirements**: TIME-01, TIME-02, SCEN-01, SCEN-02
**Success Criteria** (what must be TRUE):

  1. The program evaluates the grid at multiple times of day (e.g. morning, mid-afternoon
     peak, evening, pre-dawn night) via a time-dependent diurnal multiplier (TIME-01).

  2. For identical baseline weather, the urban-rural temperature gap is larger at night than
     at mid-afternoon — `gap_night > gap_afternoon` — verified by an automated assertion, and
     night-edge cells still return sane near-air-temp heat-index values (TIME-02, re-verifies HEAT-02).

  3. The program runs a baseline plus at least one "add trees" and one "more concrete"
     scenario by copy-then-mutate, so the baseline grid is never mutated (SCEN-01).

  4. For each scenario the program reports the per-cell and city-average temperature change
     versus the same baseline at the same timesteps (SCEN-02).
**Plans**: TBD

Plans:

- [ ] 03-01: diurnal_mod — elemental pure time-of-day multiplier (small mid-afternoon, max pre-dawn); evaluate grid at ≥3 timesteps
- [ ] 03-02: scenario_mod — type(scenario_t), copy-then-mutate baseline, "add trees" / "more concrete" runs; per-cell & city-average deltas
- [ ] 03-03: summary_mod gap reduction + automated `gap_night > gap_afternoon` and night-sanity invariant tests

### Phase 4: CSV Export & Console Summary

**Goal**: The terminal deliverable — a full end-to-end run (`fpm run`) that loads the grid,
sweeps physics across times and scenarios, writes a clean deterministic CSV for external
plotting, and prints a console summary of the hottest/coolest cells, city average, and
urban-rural gap.
**Depends on**: Phase 3
**Requirements**: OUT-01, OUT-02
**Success Criteria** (what must be TRUE):

  1. The program exports results to CSV with one row per cell × timestep × scenario in a
     deterministic column order (grid indices, time label, scenario label, air temp,
     feels-like, UHI offset) (OUT-01).

  2. The CSV parses cleanly in Excel / Python / gnuplot — `.` decimal separators, a header
     row, and width-free formats (`F0.x`/`g0`) so no value ever prints `*****`.

  3. When run, the program prints a console summary: hottest and coolest cells, city-average
     feels-like, and the urban-rural gap, per timestep (OUT-02).

  4. The full pipeline runs end-to-end from a single `fpm run`: load → physics → diurnal →
     scenarios → CSV + summary, with no manual intermediate steps.
**Plans**: TBD

Plans:

- [ ] 04-01: io_mod writer — deterministic CSV (cell × time × scenario), header row, comma-delimited width-free formats, iostat-checked
- [ ] 04-02: summary_mod console report (hottest/coolest, city average, urban-rural gap per timestep) + final driver wiring and end-to-end run

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Build Scaffold & Grid Loader | 3/3 | ✅ Complete | 2026-06-28 |
| 2. Feels-Like Physics (Heat Index + UHI Offset) | 0/3 | Not started | - |
| 3. Day-Night Cycle & Scenario Comparison | 0/3 | Not started | - |
| 4. CSV Export & Console Summary | 0/2 | Not started | - |
