# Phase 3: Day-Night Cycle & Scenario Comparison - Context

**Gathered:** 2026-06-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Evaluate the HCMC grid across **multiple times of day** and across a **baseline plus
what-if scenarios**, reproducing the signature result that the **urban–rural feels-like gap
is larger pre-dawn than mid-afternoon**, and quantifying how each scenario warms/cools the
city against an **immutable baseline**. Covers TIME-01, TIME-02, SCEN-01, SCEN-02.

Per timestep, two diurnal knobs apply: a spatially-uniform base air temperature `base(t)`
that swings across the day, and the existing UHI multiplier `m(t)` that scales the
land-cover offset. Scenarios are built by **copy-then-mutate** (one driver changed) and
reported as per-cell and city-average deltas versus baseline at the same timesteps.

This phase does **NOT** own CSV export or the full console summary (Phase 4 — OUT-01/OUT-02).
Phase 3 delivers the diurnal + scenario engine, the `gap_night > gap_afternoon` /
night-sanity invariant tests, and only **minimal** console evidence. It ends when the
night-amplified gap and scenario-delta invariants hold under test and the driver shows the
gap growing toward pre-dawn.

</domain>

<decisions>
## Implementation Decisions

### Diurnal Model (TIME-01, TIME-02)
- **D-01:** **Two diurnal knobs per timestep.** (a) A spatially-uniform base air temperature
  `base(t)` that swings across the day, and (b) the diurnal multiplier `m(t)` that scales the
  UHI land-cover offset. Per-cell per-timestep pipeline (extends Phase 2):
  `t_adj = base(t) + m(t)·ΔT_UHI`, then `feels = max(HeatIndex(c_to_f(t_adj), rh_cell), t_adj)`
  (floor vs `t_adj` per Phase 2 D-09). `ΔT_UHI` is the unchanged Phase-2 offset.
- **D-02:** **base(t) carries absolute realism; m(t) carries the gap.** Because `base(t)` is
  uniform in space at each time, it **cancels in the urban–rural gap** — the gap is driven
  purely by `m(t)·offset` (consistent with PITFALLS **B2**: "offset, not baseline temp,
  carries the gap"). The base swing only makes absolute temps believable (afternoon hottest)
  and naturally pushes pre-dawn / edge cells toward or below the 80 °F Steadman threshold,
  **re-verifying HEAT-02** as TIME-02 requires.
- **D-03:** **4 timesteps** — morning, mid-afternoon peak, evening, pre-dawn — matching the
  existing `m_morning/m_afternoon/m_evening/m_predawn` (0.5 / 0.3 / 0.8 / 1.0). Add a parallel
  `base_morning/base_afternoon/base_evening/base_predawn` lookup. Afternoon base hottest
  (~33 °C), pre-dawn coolest (~24–26 °C) per FEATURES HCMC daily range; `m` smallest at
  afternoon, largest pre-dawn (the established direction).
- **D-04:** **Lookup table in config, NOT a smooth curve.** The `base_*` values join the
  `coeffs.nml` namelist next to `m_*` — editable without recompile (GRID-04). Smooth cosine
  diurnal curve (**REFN-03**) stays v2. Exact default `base_*` values are research/planning
  discretion within FEATURES HCMC ranges.

### Scenario Engine (SCEN-01, SCEN-02)
- **D-05:** **Hybrid definition.** `type(scenario_t)` and the two required scenarios
  ("add trees", "more concrete") are **structured in code** (`scenario_mod`); the mutation
  **magnitudes** (`add_trees_delta`, `concrete_delta`) live in `coeffs.nml`, tunable without
  recompile. (Full config-driven arbitrary scenario lists are deferred — see Deferred Ideas.)
- **D-06:** **Exactly one driver per scenario** (PITFALLS **B5**). "add trees" → `tree +=
  add_trees_delta`; "more concrete" → `building += concrete_delta`. Applied **uniformly to
  all cells**, result **clamped to [0,1]**. Already-green cells (Can Gio) clamp → little
  change; low-tree urban core changes most — tells the story without special-casing
  `is_urban`. "more concrete" does **NOT** flip `is_urban` (that would change a second driver).
- **D-07:** **Immutable baseline via copy-then-mutate.** A scenario grid is an intrinsic
  assignment of the baseline `grid_t` (Fortran deep-copies the allocatable `cells(:,:)`),
  then the copy is mutated. The baseline `grid_t` is **never** mutated (SCEN-01). Allocate
  once; do **NOT** re-allocate inside the timestep/scenario loop (PITFALLS **A8**); beware the
  `save`-attribute-on-declaration-init trap in per-timestep/scenario routines (PITFALLS **A4**).
- **D-08:** **Deltas reported apples-to-apples** (SCEN-02, B5): `feels_scenario −
  feels_baseline` at the **same timestep** and same baseline weather, per cell and as a
  **city-average** (mean over occupied cells). Never compare a day baseline to a night scenario.

### Gap Metric & Calibration (TIME-02)
- **D-09:** **Gap = `mean(feels over is_urban occupied cells) − mean(feels over rural occupied
  cells)`**, evaluated per timestep. Robust mean-vs-mean (canopy-layer UHI); reusable by the
  Phase 4 console summary.
- **D-10:** **Test policy — hard direction, soft magnitude.** HARD assertion:
  `gap_predawn > gap_afternoon` for identical baseline weather (B2), plus **night-sanity**
  (pre-dawn edge cells return sane near-air feels-like, re-verifying HEAT-02). The magnitude
  target (peak night mean-gap ~3–8 °C) is a **SOFT check only** — printed/warned, does **NOT**
  fail the build — honoring Phase 2 **D-11** ("verify by rank/sign, not absolute °C"). Tune
  `m_*` / weights / `base_*` toward ~3–8 °C during execution (STATE blocker).
- **D-11:** **Invariant tests use synthetic controlled archetypes built in-test** (mirroring
  Phase 2 D-10) for robustness to seed-data edits — test the model, not the data file. Exact
  archetypes are research/planning discretion; reuse Phase-2 archetype parameters.

### Output Surfacing (boundary with Phase 4)
- **D-12:** Phase 3 delivers the engine + invariant tests; the driver prints **minimal**
  console evidence — e.g. one line per timestep showing the mean-gap rising toward pre-dawn,
  and one line per scenario showing the city-average delta. The full human-facing report
  (hottest/coolest/avg/gap table — OUT-02) and CSV export (OUT-01) are **Phase 4**. Keep
  feels-like values reachable from the driver so Phase 4 wires CSV/summary without rework.

### Claude's Discretion
- Module names/APIs (roadmap suggests `diurnal_mod`, `scenario_mod`, `summary_mod`); how
  `m(t)` and `base(t)` thread into the feels pipeline (e.g. add an `m` argument + per-timestep
  base to `feels_like_c`, keeping it `elemental pure`); derived-type/field names; exact default
  `base_*` and delta values within research ranges; exact in-test archetypes; and the precise
  minimal console format — all left to research/planning provided the decisions above hold.
  Kernels stay `elemental pure`, no global state, no re-allocation in loops, `_wp` on every
  literal, no integer division.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 3: Day-Night Cycle & Scenario Comparison" — goal, 4 success
  criteria, plan breakdown (03-01 diurnal_mod, 03-02 scenario_mod, 03-03 summary_mod gap +
  tests).
- `.planning/REQUIREMENTS.md` — TIME-01, TIME-02, SCEN-01, SCEN-02 (the four delivered here).
- `.planning/PROJECT.md` — Core Value (believable spatial pattern + night gap persists),
  Constraints (fpm + real64, illustrative-not-predictive), Key Decisions (day–night cycle,
  what-if scenarios).

### Science: diurnal signature, scenarios, baselines (most relevant)
- `.planning/research/FEATURES.md` §3 "Diurnal signature" (`m(t)` on the offset, small
  afternoon / large pre-dawn; the #1 pitfall is getting it backwards), §"What-if scenario
  comparison" (re-run same kernel with perturbed B/V; per-cell + city-average Δ), §"HCMC
  Baselines" (daily range ~24 °C pre-dawn → ~33 °C afternoon; ~28 °C generic; 70–85% RH;
  realistic 3–8 °C night UHI).
- `.planning/research/PITFALLS.md` §**B2** (diurnal UHI backwards — gap largest at NIGHT;
  hard `gap_night > gap_afternoon` test), §**B5** (non-apples scenarios — one driver,
  immutable baseline, same timestep), §**A8** (allocatable handling — allocate once, no
  re-allocate in the timestep/scenario loop), §**A4** (declaration-init `save`-attribute trap
  in per-timestep/scenario routines), §**A9/A10** (output `*****`/locale — context for the
  minimal console line; full handling is Phase 4).

### Toolchain & testing
- `.planning/research/STACK.md` — strict dev gfortran flags vs `-O2` release; test-drive
  harness. **NOTE:** fpm 0.13.0 rejects `[profiles.*.gfortran]` in the manifest — pass strict
  dev flags via `fpm test --flag "..."` (not the manifest).
- `.planning/research/ARCHITECTURE.md` — module decomposition / build order placing
  diurnal/scenario above the physics kernels; pure-kernel design, allocate-once grid.

### Phase 2 contract (consumed directly)
- `.planning/phases/02-feels-like-physics-heat-index-uhi-offset/02-CONTEXT.md` — feels pipeline
  (D-01 hybrid base, D-03 single offset budget, D-06 `m=1` reserved for Phase 3, D-09 floor vs
  `t_adj`, D-10/D-11 in-test archetypes + rank/sign testing). Phase 3 wraps the same offset with
  `m(t)` and per-timestep `base(t)`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/grid.f90` — `type(coeffs_t)` **already carries** `m_morning/m_afternoon/m_evening/
  m_predawn` (dormant since Phase 2). Add the parallel `base_*` lookup and the scenario
  deltas (`add_trees_delta`, `concrete_delta`) here. `type(cell)` carries `building`, `tree`,
  `is_urban`, `occupied` — scenarios mutate `building`/`tree` only. `grid_t` has an
  allocatable `cells(:,:)` → **intrinsic assignment deep-copies** it (the copy-then-mutate
  primitive for D-07). `allocate_grid` is allocate-once.
- `src/feels.f90` `feels_like_c` — currently computes the offset internally at full strength
  (`m = 1`). Phase 3's integration point: thread `m(t)` to scale the offset and feed
  `base(t)` as the base temp, keeping it `elemental pure` (exact signature = planner's call).
- `src/uhi.f90` `uhi_offset` — **unchanged**; scenarios only change its `building`/`tree`
  inputs. `src/heat_index.f90`, `src/constants.f90` (`c_to_f`/`f_to_c`, range consts) — reused.
- `src/io.f90` `read_coeffs_nml` + `data/coeffs.nml` — insertion point for the new `base_*`
  and delta namelist variables (follow the existing pattern; keep load-time validation).
- `app/main.f90` — driver loops occupied cells at a single time; Phase 3 extends it to loop
  timesteps × scenarios with the minimal console print (D-12).
- `test/` uses **test-drive** (`test_heat_index.f90`, `test_uhi.f90`, `test_ordering.f90`,
  fixtures) — new diurnal / scenario / gap tests follow this harness and the in-test-archetype
  style of `test_ordering.f90`.

### Established Patterns
- `private` modules with explicit `public`, one module per file, `use ..., only:`; kernels
  `elemental pure`, no global state. Load-time fail-loud validation; pure hot path assumes
  validated `real64` inputs. Tests assert **rank/sign, not absolute °C** (D-11).

### Integration Points
- `diurnal_mod` provides `m(t)` and `base(t)`; the feels pipeline scales the Phase-2 offset by
  `m(t)` over `base(t)`. `scenario_mod` deep-copies the baseline grid and mutates one driver.
  A gap/reduction routine (`summary_mod`) computes mean-urban − mean-rural per timestep — the
  same reduction Phase 4 reuses for the console summary and CSV.

</code_context>

<specifics>
## Specific Ideas

- The teaching payoff is the **shape**: mid-afternoon is absolute-hottest yet has the
  *smallest* urban–rural gap, while pre-dawn is cooler yet has the *largest* gap. A learner
  should see this emerge from the minimal console line (and later the Phase-4 CSV plot).
- Scenario delta magnitudes live in `coeffs.nml` precisely so a learner can crank "add trees"
  and watch the city-average cool, without recompiling.
- The soft magnitude check doubles as a **calibration aid** — print something like
  "night gap = X °C (expect ~3–8 °C)" so tuning `m_*`/weights/`base_*` is guided, not blind.

</specifics>

<deferred>
## Deferred Ideas

- **Smooth cosine diurnal curve** replacing the 4-point lookup (**REFN-03**) — v2.
- **CSV export** (one row per cell × timestep × scenario) and the **full console summary**
  (hottest/coolest/avg/gap table) — **Phase 4** (OUT-01, OUT-02).
- **Fully config-driven scenario list** (arbitrary user-defined scenarios read from a data
  file) — possible v2 enhancement; v1 keeps the 2 structured scenarios with config-tuned deltas
  (D-05).
- **Humidex toggle** (REFN-01), **more districts / finer archetypes** (REFN-04), **seasonal
  dry/wet baselines** (REFN-05) — v2.
- **Time-varying / per-scenario humidity** — out of scope; `rh` stays per-cell static
  (Phase 2 D-01/D-02). Only temperature and land-cover drivers move in Phase 3.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 3-Day-Night Cycle & Scenario Comparison*
*Context gathered: 2026-06-29*
</content>
</invoke>
