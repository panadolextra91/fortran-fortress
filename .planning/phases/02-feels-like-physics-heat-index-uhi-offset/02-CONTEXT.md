# Phase 2: Feels-Like Physics (Heat Index + UHI Offset) - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Compute a believable per-cell **feels-like (apparent) temperature** for a **single
baseline time**: a NWS heat index (from air temperature + relative humidity), whose
temperature input is perturbed once by an **additive UHI land-cover offset** (building +
urban warm; tree + water cool). The headline spatial ordering — dense, treeless urban
cells hotter than green / waterfront / rural cells for the same baseline weather — must
hold and be **locked by an automated test**. Covers HEAT-01, HEAT-02, UHI-01, UHI-02.

This phase does **NOT** implement the day–night diurnal cycle, what-if scenarios, or CSV
export (Phases 3–4). It evaluates the grid once, at full offset (`m = 1`), and writes
results only to the console wiring already present in `app/main.f90`. Phase 2 ends when
every occupied cell has a sane feels-like value and the urban>green/waterfront/rural
ordering test passes.

</domain>

<decisions>
## Implementation Decisions

### Baseline Weather Source (HEAT-01)
- **D-01:** **Hybrid base.** `feels_like(cell) = HeatIndex(t_base + ΔT_UHI, rh_cell)` —
  the temperature base is the **uniform** `coeffs%t_base` for every cell, while relative
  humidity is taken **per-cell** from `cell%rh` (loaded from the CSV in Phase 1). Spatial
  variation in temperature therefore comes *only* from the land-cover offset (keeps UHI-02
  "same baseline weather" honest), but humidity is allowed to vary district to district.
- **D-02:** **Water–humidity coupling kept clean (PITFALLS B3).** `w_water` acts on the
  **temperature input only** (via the offset). Per-cell `rh` is consumed as-is from the
  data file — water proximity does NOT additionally raise RH in code. This prevents the
  double-count where water both lowers T and raises the heat index. The UHI-02 ordering
  test guarantees waterfront cells still end up cooler overall.

### UHI Offset Model (UHI-01)
- **D-03:** **Single temperature budget, applied once.**
  `ΔT_UHI = w_build·B + w_urban·U − w_tree·V − w_water·Wprox`, added to the heat-index
  temperature input (NOT a second post-hoc offset on the final heat index — PITFALLS B3).
  With the Phase-1 weights (`w_build=3.0, w_urban=1.0, w_tree=2.5, w_water=2.0`) and
  drivers in [0,1] / {0,1}, the offset spans ≈ **−4.5 … +4 °C** — each driver stays
  single-digit °C as UHI-01 requires.
- **D-04:** **Water-proximity = continuous exponential decay.** `Wprox = exp(−water_km/d0)`
  (not the simple near/far term). This **pulls REFN-02 forward into v1** — REFN-02 must
  move out of v2-deferred when REQUIREMENTS.md is next updated.
- **D-05:** Add a tunable scale length **`d0`** to `data/coeffs.nml` (default ≈ **2.5 km**,
  per FEATURES.md §2). It loads at runtime like the other coefficients (GRID-04 — editable
  without recompiling); exact default value is Claude's discretion within ~2–3 km.
- **D-06:** **No diurnal scaling in Phase 2.** The offset is evaluated at the reference
  multiplier `m = 1` (full offset). The time-of-day multiplier `m(t)` and the `m_*`
  coefficients already in `coeffs.nml` belong to **Phase 3** — Phase 2 must not consume them.

### Heat Index Algorithm (HEAT-01, HEAT-02)
- **D-07:** **Full NWS algorithm, two-branch.** Simple Steadman average when the result
  would be < 80 °F; full Rothfusz regression at/above 80 °F — **plus both documented
  adjustments**: add when RH > 85 % & T 80–87 °F (relevant for humid HCMC), subtract when
  RH < 13 % & T 80–112 °F.
- **D-08:** **Unit convention:** compute internally in **°F** with the canonical
  coefficients, convert °C↔°F at the boundary (`F = C·9/5+32`). Every literal carries a
  `_wp` suffix (PITFALLS A1). Never mix °C-coefficient and °F-coefficient variants.
- **D-09:** **Floor guarantees HEAT-02:** `feels_like = max(HeatIndex(...), t_air)` so a
  cool/night cell never returns a feels-like below its air temperature. Verified by a
  boundary test at the 80 °F threshold and against published NWS reference values.

### Ordering Test Design (UHI-02)
- **D-10:** **Synthetic controlled archetypes, built inside the test** — construct
  archetype cells in-test (industrial: high B / V≈0 / urban; District-1 core: high B / low
  V / urban; park: high V / urban; Can Gio: rural + water-near; rural fringe) and assert
  the rank ordering. Robust to seed-data edits; tests the *model*, not the data file.
- **D-11:** **Add property-monotonicity checks alongside the ordering assert:** holding
  other drivers fixed, ↑building → ↑feels-like, ↑tree → ↓feels-like, ↑Wprox → ↓feels-like,
  urban > rural. Verify by *rank/sign*, not absolute °C (FEATURES.md).

### Claude's Discretion
- Module names/APIs (roadmap suggests `heat_index_mod`, `uhi_mod`), derived-type field
  names, the exact `d0` default within ~2–3 km, and how the feels-like values are surfaced
  on the existing console output — all left to research/planning, provided the decisions
  above hold. Kernels must be **`elemental pure`, no global state**, consuming `grid_t` +
  `coeffs_t` (Phase-1 integration contract).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 2: Feels-Like Physics (Heat Index + UHI Offset)" — goal,
  4 success criteria, plan breakdown (02-01 heat_index_mod, 02-02 uhi_mod, 02-03 wire +
  ordering test).
- `.planning/REQUIREMENTS.md` — HEAT-01, HEAT-02, UHI-01, UHI-02 (the four delivered here);
  **REFN-02** (now pulled into v1 by D-04 — update on next requirements pass).
- `.planning/PROJECT.md` — Core Value (believable spatial pattern), Constraints (fpm +
  real64), Key Decisions ("Heat index + UHI offset model").

### Science formulas & pitfalls (most relevant for this phase)
- `.planning/research/FEATURES.md` §"Candidate Formulas" — (a) NWS simple Steadman, (b)
  Rothfusz regression + the RH<13 % / RH>85 % adjustments, valid ranges; §2 additive UHI
  offset (`Wprox = exp(−d/d0)`, d0≈2–3 km, suggested weights); §"HCMC Baselines" archetype
  parameters for the test cells.
- `.planning/research/PITFALLS.md` §B1 (heat-index valid-range guard — THE headline science
  pitfall; implement two-branch + floor), §B3 (single temperature budget, no double-count,
  waterfront-cooler check), §B6 (air vs surface vs feels-like — name `t_air`/`feels_like`,
  air-UHI not surface-UHI); §A1 (`_wp` on every literal — Rothfusz cancellation),
  §A2 (no integer division in the offset), §A7 (all procedures in modules / explicit
  interfaces for elemental kernels).
- `.planning/research/STACK.md` — gfortran strict dev flags (`-fcheck=all -Wall -Wextra
  -fimplicit-none -finit-real=snan`) vs `-O2` release; test-drive harness usage.
- `.planning/research/ARCHITECTURE.md` — module decomposition / build order placing the
  physics kernels above `grid_mod`; pure-kernel design.

### Phase 1 contract (consumed directly)
- `.planning/phases/01-build-scaffold-grid-loader/01-CONTEXT.md` — data file format
  (CSV grid + namelist coeffs), `grid_t`/`cell`/`coeffs_t` shapes, allocate-once, fail-loud
  validation; integration note "Phase 2 physics consumes grid_t + coeffs directly".

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/grid.f90` — `type(cell)` already carries `t_air, rh, water_km, building, tree,
  is_urban, occupied`; `type(coeffs_t)` already carries `w_build, w_urban, w_tree, w_water`
  and `t_base, rh_base`. Phase 2 reads these directly — no new loader work, only physics.
- `src/io.f90` `read_coeffs_nml` + `data/coeffs.nml` — the namelist round-trip is the
  insertion point for the new **`d0`** coefficient (D-05): add the variable, default, and
  `namelist /coeffs/` entry following the existing pattern.
- `src/kinds.f90` (`wp = real64`) and `src/constants.f90` (`T_MIN/T_MAX`, etc.) — reuse for
  the kernels; add any new physics constants (e.g. °F conversion) to `constants_mod`.
- `app/main.f90` — driver already loads coeffs + grid and loops occupied cells; 02-03
  wires the feels-like evaluation and console print into this existing loop.
- `test/` already uses **test-drive** (`test_io.f90`, `test_e2e_load.f90`, `fixtures/`) —
  the new heat-index, UHI, and ordering tests follow this harness and layout.

### Established Patterns
- Modules are `private` with explicit `public` exports, one module per file, `use ..., only:`.
  New `heat_index_mod` / `uhi_mod` follow this; keep kernels `elemental pure`.
- Phase-1 validation is **fail-loud with line numbers** — physics kernels stay pure and
  assume already-validated `real64` inputs (no re-validation in the hot path).

### Integration Points
- Kernels consume `cell`/`coeffs_t` and feed the existing `app/main.f90` cell loop.
- Designed so Phase 3 can wrap the same offset with `m(t)` and Phase 4 can read feels-like
  into the CSV writer — keep the feels-like value reachable from `grid_t`/the driver.

</code_context>

<specifics>
## Specific Ideas

- The illustrative story must stay **pedagogically honest**: same baseline temperature
  everywhere, so the heat differences are explained by *land cover alone* (why D-01 uses a
  uniform `t_base` rather than baking the answer into per-cell air temps).
- HCMC humid-night realism is why the **RH>85 % heat-index adjustment** (D-07) is kept, not
  dropped.
- `d0` and the UHI weights live in `coeffs.nml` precisely so a learner can tune them and
  watch the map respond without recompiling.

</specifics>

<deferred>
## Deferred Ideas

- **Diurnal multiplier `m(t)` and multi-timestep evaluation** — Phase 3 (TIME-01/TIME-02).
  The `m_*` coefficients already loaded are dormant until then.
- **What-if scenarios / immutable-baseline copy-then-mutate** — Phase 3 (SCEN-01/SCEN-02).
- **CSV export of feels-like / UHI offset columns** — Phase 4 (OUT-01).
- **Humidex toggle** (REFN-01), **smooth cosine diurnal curve** (REFN-03), **more
  districts/finer archetypes** (REFN-04), **seasonal runs** (REFN-05) — v2.
- **Note:** REFN-02 (continuous distance-to-water decay) is **no longer deferred** — D-04
  brings it into v1.
- **Tuning weights so the night gap lands in ~3–8 °C** — a Phase-3 calibration concern
  (depends on the diurnal `m(t)`). Phase 2 only needs the offset to produce correct
  *ordering* at full offset, not a calibrated night-gap magnitude.

</deferred>

---

*Phase: 2-Feels-Like Physics (Heat Index + UHI Offset)*
*Context gathered: 2026-06-28*
