# Project Research Summary

**Project:** Fortran Fortress — Ho Chi Minh City Urban Heat Island Simulator
**Domain:** Modern Fortran scientific-computing program (2D UHI grid simulator, batch CSV output)
**Researched:** 2026-06-28
**Confidence:** HIGH

## Executive Summary

This is a **batch scientific-computing pipeline** in modern Fortran: read district seed data once, sweep a stack of pure physics kernels over a 2D grid across scenarios and times of day, write CSV, print a summary, exit. Experts build this as a thin `program` driver orchestrating a layered, acyclic stack of single-responsibility `module`s (kinds → constants → grid → physics → orchestration → I/O → main), with all physics written as `elemental pure` functions that broadcast over the grid arrays. The standard language is sufficient — **no external libraries are required or recommended for v1**; `gfortran` 16 intrinsics cover everything, and the UHI model is a transparent **additive offset** (building↑/urban↑ warm; tree↓/water↓ cool), deliberately NOT CFD.

The recommended approach is dependency-light and correctness-first: develop with aggressive runtime checks (`-fcheck=all -ffpe-trap -finit-real=snan`), keep all tunable coefficients and district data in editable config/data files (not source), and structure scenarios/timesteps as outer loops over stateless kernels. There is one open **build-system decision the roadmap should make explicitly**: research recommends **fpm (Fortran Package Manager)** over the originally-stated plain Makefile, because fpm auto-resolves Fortran module compile-order (the single biggest hand-written-Makefile pain point) and gives `fpm test`/`fpm run` for free. A plain Makefile remains an acceptable fallback that honors the existing scaffold *provided* module dependency order is encoded as explicit object prerequisites.

The two highest-stakes risks are both **scientific correctness** issues that make the map *look* fine but be wrong: (1) the NOAA/NWS **heat index is only valid above ~26.7 °C / 40% RH** — and HCMC nights sit right at that lower edge, exactly where the signature result lives — so a two-branch Steadman-below / Rothfusz-above guard is mandatory; and (2) the **urban–rural gap must peak at NIGHT, not mid-afternoon** — inverting this destroys the core value. Both must be locked down with automated invariant tests (`gap_night > gap_afternoon`; night cells return sane near-air-temp values). Fortran-specific traps (unsuffixed real literals causing precision loss, integer division zeroing offsets, stale `.mod` files, uninitialized accumulators) are well-understood and prevented by P1 conventions plus dev-build flags.

## Key Findings

### Recommended Stack

The standard language suffices; resist adding dependencies. Use `gfortran` 16.1.0 with `-std=f2018`, `real64` kinds from `iso_fortran_env`, `implicit none` everywhere. Config (UHI coefficients, times, scenarios) via Fortran `namelist` or a simple delimited table; per-district seed grid via a documented delimited CSV/TSV with a header. CSV output via plain formatted `write` (use `F0.x`/`g0` to avoid `*****` overflow). See STACK.md.

**Core technologies:**
- **gfortran (GCC 16.1.0)** — compiler — already installed; de-facto free Fortran compiler with excellent F2018 coverage and strong runtime checks for a learner.
- **fpm 0.13.0 (recommended) OR plain GNU Makefile (fallback)** — build/test/run — fpm auto-derives module compile order; Makefile honors the existing scaffold but needs explicit dependency ordering. **Decision required.**
- **test-drive 0.6.0 (with fpm) OR a ~30-line hand-rolled assert module (with Makefile)** — testing — both standard-Fortran-only; focus tests on science invariants.
- **iso_fortran_env (`real64`)** — portable precision — one precision knob, avoids accidental single-precision physics.
- **No external libraries** (skip fortran-stdlib, CSV libs, OpenMP, CMake for v1) — intrinsics (`sum`/`maxval`/`maxloc`/`count`) cover the need.

### Expected Features

The science features are where "right vs wrong" lives. See FEATURES.md.

**Must have (table stakes):**
- Per-cell heat-index / apparent temperature **with range guard** (Steadman below ~80 °F ↔ Rothfusz above) — skipping the guard produces nonsense at night.
- Additive UHI offset (building↑, urban↑ warm; tree↓, water↓ cool) — the core spatial pattern.
- Diurnal evaluation at ≥3 times with a **night-amplified** offset multiplier — the signature result.
- Grid loaded from an editable data file (not hard-coded) with range validation.
- CSV export (cell × time × scenario) + console summary (hottest/coolest/avg/gap).

**Should have (competitive):**
- What-if scenario comparison ("add trees" vs "more concrete") — quantifies "+X trees → −Y °C"; near-free once the kernel is pure.
- Realistic HCMC archetypes (District 1 hot, industrial hottest, parks cool, Can Gio coolest, rural fringe reference) — relatable and sanity-checkable.
- Distance-to-water cooling term; explicit night-vs-day gap reporting.

**Defer (v1.x / v2+):**
- Humidex toggle, continuous distance-to-water decay, smooth cosine diurnal curve, more districts.
- Wind/sea-breeze advection, seasonal runs, parametric radiative term. (Full CFD, forecasting, live APIs, per-building resolution, GUI are explicit anti-features.)

### Architecture Approach

A thin driver over a strictly-layered, acyclic module stack. Physics kernels are `elemental pure` (no I/O, no module state) so they broadcast over grid component arrays and are trivially unit-testable; scenarios and timesteps are outer loops in an orchestration module; all I/O is confined to `io_mod` with status-flag error handling. No global mutable state — `grid_t`/`scenario_t` values are threaded through arguments. See ARCHITECTURE.md.

**Major components:**
1. **Foundation** (`kinds_mod`, `constants_mod`) — precision + named coefficients.
2. **Data/IO** (`grid_mod` derived types, `io_mod` read/write CSV) — allocatable grid sized at runtime from the data file.
3. **Domain physics** (`heat_index_mod`, `uhi_mod`, `diurnal_mod`) — pure elemental kernels.
4. **Orchestration** (`scenario_mod`, `summary_mod`) — scenario/timestep loops + reductions.
5. **Driver** (`program uhi_sim`, `main.f90`) — composition root, owns exit policy.

### Critical Pitfalls

1. **Heat index out of valid range (B1)** — Rothfusz is only valid ≥~26.7 °C / 40% RH; HCMC nights breach it. Implement the full two-branch NWS algorithm (Steadman+average below 80 °F, Rothfusz above, with the documented RH adjustments); return ~air-temp below threshold, never extrapolate.
2. **Diurnal pattern inverted (B2)** — the urban–rural gap must be LARGEST pre-dawn/night, smallest mid-afternoon. Drive the gap via a time-dependent offset multiplier (not baseline temp), and enforce `gap_night > gap_afternoon` as an automated assertion. HIGH recovery cost — design it right first.
3. **Silent precision loss / integer division (A1, A2)** — suffix every real literal `_dp`; store/convert model attributes as `real(dp)` so `density/100` never integer-divides to zero. Verify output is identical across `-O0`/`-O2`.
4. **Stale `.mod` / compile-order (A3)** — declare explicit object dependencies mirroring `use` statements; `clean` must remove `*.mod`; `make clean && make` must pass. (fpm eliminates this class entirely.)
5. **Double-counted / unphysical UHI offset (B3)** — define a single temperature budget (`feels = heat_index(T_adjusted, RH_adjusted)`), modify inputs once, cap each driver to single-digit °C, keep waterfront cells cooler.

## Implications for Roadmap

All three of FEATURES, ARCHITECTURE, and PITFALLS independently converged on the **same natural phase ordering**, driven by the module dependency stack and feature dependencies. Suggested structure (7 phases):

### Phase 1: Scaffold & Build
**Rationale:** Everything depends on the build skeleton, kinds module, and compiler-flag conventions; precision/implicit-none/compile-order pitfalls are all prevented here.
**Delivers:** Project layout, kinds + constants modules, dev/release flag profiles, `make`/`fpm` build + a test target that runs clean.
**Avoids:** A1 (precision), A3 (stale `.mod`), A4 (implicit none), A5/A7 (init/interfaces).
**Decision point:** Choose **fpm vs plain Makefile** here (research recommends fpm).

### Phase 2: Grid + Data Loader
**Rationale:** The grid type and editable seed file underpin every later phase; load-time validation catches bad data before physics runs.
**Delivers:** `type(cell)`/`grid_t`, allocate-once runtime sizing, delimited-file reader with `iostat`/range validation, realistic HCMC archetype seed data.
**Implements:** Data/IO layer + foundation derived types.
**Avoids:** A2 (load as real), A6/A8 (bounds/allocatable), A10 (parsing), B4 (realistic baselines).

### Phase 3: Heat-Index Kernel
**Rationale:** Apparent temperature is the base quantity the UHI offset perturbs; must exist before offsets.
**Delivers:** `elemental pure heat_index(t_air, rh)` with the **two-branch Steadman↔Rothfusz range guard**; unit tests against published NWS reference values.
**Avoids:** B1 (range guard — THE headline science pitfall), B6 (air vs surface vs feels-like naming).

### Phase 4: UHI Offset
**Rationale:** Builds directly on the heat-index kernel; defines the single temperature budget the diurnal phase will modulate.
**Delivers:** `elemental pure uhi_offset(...)` additive model, documented tunable weights in config, monotonicity test (dense-treeless > green-waterfront).
**Avoids:** B3 (double-counting — one budget), A2 (integer division in weights).

### Phase 5: Day–Night Cycle
**Rationale:** The make-or-break phase — composes heat-index + offset across times of day to reproduce the nocturnal gap.
**Delivers:** `diurnal_factor` multiplier (small mid-afternoon, max pre-dawn), grid evaluation at ≥3 timesteps, **automated `gap_night > gap_afternoon` invariant test**.
**Avoids:** B2 (inverted diurnal — highest recovery cost), re-verifies B1 at night-edge temperatures.

### Phase 6: Scenarios
**Rationale:** A near-free payoff once kernels are pure — re-runs the same kernel on a copied, immutable baseline with one perturbed driver.
**Delivers:** `scenario_t`, copy-then-mutate baseline, "add trees" / "more concrete" runs, per-cell/per-timestep deltas.
**Avoids:** B5 (non-apples comparison — vary one driver vs immutable baseline).

### Phase 7: CSV Output + Summary
**Rationale:** Terminal deliverable; depends on all prior results existing.
**Delivers:** Deterministic CSV (cell × time × scenario) with safe formats + header, console summary (hottest/coolest/city-avg/gap).
**Avoids:** A9 (`*****`/locale/decimal-comma), A5 (uninitialized accumulators), B6 (unambiguous column labels).

### Phase Ordering Rationale

- **Strict module dependency stack** dictates the order: foundation/build → grid+IO → physics kernels (heat index before offset before diurnal) → orchestration (scenarios) → output. Upper layers cannot compile or be tested before lower ones exist.
- **Feature dependencies confirm it:** offset perturbs the heat-index input; diurnal modulates the offset; scenarios re-run the kernel; CSV/summary consume the results — a clean linear chain.
- **Pitfall prevention is front-loaded:** P1 sets flags/conventions, P2 validates data, and the two highest-risk science items (B1 in P3, B2 in P5) each land in dedicated phases with their own invariant tests.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Heat Index):** Exact NWS two-branch algorithm + RH adjustments + °C↔°F boundary — formula is documented but the guard logic and unit conversion are precision-sensitive. Worth `--research-phase`.
- **Phase 5 (Day–Night Cycle):** Choosing a defensible diurnal multiplier shape so the night gap lands in the realistic 3–8 °C band while staying transparent — modeling judgment, not just code.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Scaffold):** Well-established Fortran build/module idioms; STACK + ARCHITECTURE already prescriptive.
- **Phase 2 (Grid/Loader):** Standard derived-type + list-directed read patterns.
- **Phase 6 (Scenarios) / Phase 7 (CSV+Summary):** Mechanical once kernels and formats are set.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against fpm/stdlib/test-drive releases + gfortran docs; standard-language stance is well-founded. |
| Features | HIGH | Heat-index formulas and diurnal physics from primary NOAA/AMS sources; HCMC baselines from converging climate sources. |
| Architecture | HIGH | Stable, non-volatile modern-Fortran language facts and idioms; existing scaffold already demonstrates the build pattern. |
| Pitfalls | HIGH | Fortran tooling well-established; UHI/heat-index science verified against NOAA WPC and AMS/Nature. |

**Overall confidence:** HIGH

### Gaps to Address

- **Build-system decision (fpm vs Makefile):** Not a research gap but an explicit choice for the user/roadmap to lock in at Phase 1. Recommendation: fpm; fallback Makefile must encode explicit object-order prerequisites.
- **UHI weight calibration:** Weights are *illustrative, not fitted* — tune in Phase 4/5 so the peak night urban–rural gap lands in 3–8 °C and ordering is always urban>rural. Budget tuning time + a monotonicity test, not code.
- **LST vs air temperature:** HCMC papers report satellite land-surface temperature, which peaks by day; use it only for ranking sanity, set air-temp baselines (~28 °C, 70–85% RH) from climate normals. Surface UHI ≠ air UHI (B6).
- **Heat-index unit convention:** Run the canonical Rothfusz in °F, present in °C; mixing conventions is the classic bug — validate at the 80 °F boundary in Phase 3.

## Sources

### Primary (HIGH confidence)
- NOAA/NWS Weather Prediction Center — Heat Index Equation (Rothfusz regression, valid range, Steadman branch, RH adjustments).
- AMS J. Appl. Meteor. & Climatology — nocturnal heat island via urban canyon structure / heat storage.
- Nature Communications — density & morphology vs UHI intensity.
- Stull, *Practical Meteorology* — apparent temperature indices (humidex/heat index).
- fpm 0.13.0, fortran-stdlib 0.8.1, test-drive 0.6.0 release notes; gfortran/GCC 16 documentation (flags, `.mod` compile order).
- Fortran 2008/2018 language semantics (elemental/pure, allocatable, derived types, `iso_fortran_env`).

### Secondary (MEDIUM confidence)
- AccScience/AJWEP, ScienceDirect, PMC — HCMC SUHI assessments (used for ranking/archetype sanity, not air-temp truth).
- HCMC climate normals (climatestotravel, weather-atlas, weatherspark) — baseline temperature/humidity ranges.
- Fortran-lang community best-practice guidance — module-everything, allocate-once, kinds conventions.

### Tertiary (LOW confidence)
- Illustrative UHI weight magnitudes — chosen, not fitted; validate qualitatively during Phase 4/5.

---
*Research completed: 2026-06-28*
*Ready for roadmap: yes*
