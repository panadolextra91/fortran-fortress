# Phase 3: Day-Night Cycle & Scenario Comparison - Research

**Researched:** 2026-06-29
**Domain:** Modern Fortran scientific computing — diurnal UHI modulation + immutable-baseline what-if scenarios (HCMC heat-island simulator)
**Confidence:** HIGH (science cited from curated HIGH-confidence research; toolchain verified; numeric defaults worked through against real Phase-2 weights and confirmed)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Two diurnal knobs per timestep — (a) spatially-uniform base air temp `base(t)`, (b) diurnal multiplier `m(t)` scaling the UHI offset. Per-cell per-timestep pipeline: `t_adj = base(t) + m(t)·ΔT_UHI`, then `feels = max(HeatIndex(c_to_f(t_adj), rh_cell), t_adj)` (floor vs `t_adj` per Phase 2 D-09). `ΔT_UHI` is the unchanged Phase-2 offset.
- **D-02:** `base(t)` carries absolute realism; `m(t)` carries the gap. Because `base(t)` is spatially uniform it cancels in the urban–rural gap (PITFALLS B2) — the gap is driven by `m(t)·offset`. The base swing makes absolute temps believable and pushes pre-dawn/edge cells toward/below the 80 °F Steadman threshold, re-verifying HEAT-02.
- **D-03:** 4 timesteps — morning, mid-afternoon peak, evening, pre-dawn — matching existing `m_morning/m_afternoon/m_evening/m_predawn` (0.5 / 0.3 / 0.8 / 1.0). Add a parallel `base_*` lookup. Afternoon base hottest (~33 °C), pre-dawn coolest (~24–26 °C); `m` smallest afternoon, largest pre-dawn.
- **D-04:** Lookup table in config, NOT a smooth curve. `base_*` join `coeffs.nml` next to `m_*` (GRID-04, no recompile). Smooth cosine curve (REFN-03) stays v2. Exact default `base_*` is research/planning discretion within FEATURES HCMC ranges.
- **D-05:** Hybrid scenario definition. `type(scenario_t)` + the two required scenarios structured in code (`scenario_mod`); mutation magnitudes (`add_trees_delta`, `concrete_delta`) live in `coeffs.nml`. Arbitrary config-driven scenario lists deferred.
- **D-06:** Exactly one driver per scenario (PITFALLS B5). "add trees" → `tree += add_trees_delta`; "more concrete" → `building += concrete_delta`. Applied uniformly to all cells, clamped to [0,1]. "more concrete" does NOT flip `is_urban`.
- **D-07:** Immutable baseline via copy-then-mutate. Scenario grid = intrinsic assignment of baseline `grid_t` (deep-copies allocatable `cells(:,:)`), then mutate the copy. Baseline never mutated (SCEN-01). Allocate once; no re-allocate inside the timestep/scenario loop (A8); beware the `save`-attribute-on-declaration-init trap (A4).
- **D-08:** Deltas apples-to-apples (SCEN-02, B5): `feels_scenario − feels_baseline` at the same timestep and same baseline weather, per cell and as a city-average (mean over occupied cells). Never compare a day baseline to a night scenario.
- **D-09:** Gap = `mean(feels over is_urban occupied cells) − mean(feels over rural occupied cells)`, per timestep. Reusable by the Phase 4 console summary.
- **D-10:** Test policy — HARD `gap_predawn > gap_afternoon` for identical baseline weather (B2) + night-sanity (pre-dawn edge cells return sane near-air feels-like, re-verifying HEAT-02). Magnitude target (~3–8 °C peak night) is a SOFT check — printed/warned, does NOT fail the build.
- **D-11:** Invariant tests use synthetic controlled archetypes built in-test (mirroring Phase 2 D-10), robust to seed-data edits. Reuse Phase-2 archetype parameters.
- **D-12:** Phase 3 delivers engine + invariant tests; driver prints MINIMAL console evidence (one line/timestep showing mean-gap rising toward pre-dawn; one line/scenario showing city-average delta). Full report (OUT-02) and CSV (OUT-01) are Phase 4. Keep feels-like values reachable from the driver.

### Claude's Discretion
- Module names/APIs (roadmap suggests `diurnal_mod`, `scenario_mod`, `summary_mod`); how `m(t)`/`base(t)` thread into the feels pipeline (e.g. add an `m` argument + per-timestep base to `feels_like_c`, keeping it `elemental pure`); derived-type/field names; exact default `base_*` and delta values within research ranges; exact in-test archetypes; precise minimal console format. Kernels stay `elemental pure`, no global state, no re-allocation in loops, `_wp` on every literal, no integer division.

### Deferred Ideas (OUT OF SCOPE)
- Smooth cosine diurnal curve (REFN-03) — v2.
- CSV export + full console summary (hottest/coolest/avg/gap table) — Phase 4 (OUT-01, OUT-02).
- Fully config-driven arbitrary scenario list — v2.
- Humidex toggle (REFN-01), more districts/finer archetypes (REFN-04), seasonal baselines (REFN-05) — v2.
- Time-varying / per-scenario humidity — out of scope; `rh` stays per-cell static (Phase 2 D-01/D-02). Only temperature and land-cover drivers move in Phase 3.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TIME-01 | Evaluate grid at multiple times of day via a time-dependent diurnal multiplier | `diurnal_mod` selectors `diurnal_m(coeffs,it)`/`diurnal_base(coeffs,it)`; driver loops `it=1..4`; `m` threaded into `feels_like_c` (Pattern 1, Code Examples §1–2) |
| TIME-02 | Urban–rural gap larger at night than mid-afternoon, automated `gap_night > gap_afternoon`; night cells stay sane | `urban_rural_gap` reduction (D-09); worked numeric check confirms `gap_predawn=+7.1 °C` vs `gap_afternoon=+0.7 °C` on Phase-2 archetypes (core urban set); floor keeps pre-dawn rural ≈ air temp (re-verifies HEAT-02) |
| SCEN-01 | Baseline + ≥1 "add trees" + ≥1 "more concrete" without mutating baseline | `scenario_mod` copy-then-mutate via intrinsic `grid_t` assignment (D-07); immutability test; A8/A4 guards |
| SCEN-02 | Per-cell and city-average temperature change vs baseline | Elementwise `feels_scenario − feels_baseline` + masked city-average; apples-to-apples at same `(it)` (D-08) |
</phase_requirements>

## Summary

Phase 3 is a thin orchestration layer over already-correct Phase-2 physics. There is **no new science to discover** — the diurnal mechanism (UHI gap peaks at night, not afternoon), the additive offset, the HCMC baselines, and the heat-index two-branch guard are all settled in the curated `.planning/research/` files at HIGH confidence. The work is (1) thread one diurnal multiplier `m` and a per-timestep `base` into the existing `elemental pure feels_like_c`, (2) add a `base_*`/delta block to `coeffs.nml`, (3) build a copy-then-mutate scenario engine on Fortran's deep-copy-on-assignment of allocatable components, and (4) write the `gap_predawn > gap_afternoon` invariant test plus per-cell/city-average scenario deltas.

The make-or-break invariant is the **diurnal direction** (PITFALLS B2). I verified it numerically against the real Phase-2 weights: with `m_predawn=1.0` vs `m_afternoon=0.3` (a 3.3× ratio) and recommended bases (`base_afternoon=33`, `base_predawn=25`), the urban–rural mean gap is **+7.1 °C pre-dawn vs +0.7 °C afternoon** on the urban-core archetype set — the HARD assertion holds with a ~6 °C margin, and the night gap lands squarely in the 3–8 °C target band. The invariant is **not** mathematically guaranteed (the heat-index `max`/`HI` nonlinearity means `base(t)` does not exactly cancel in the gap when HI is active), but the 3.3× `m` ratio gives ample margin. This is the one place to keep numerically honest.

**Primary recommendation:** Add `m` as a required scalar argument to `feels_like_c` immediately after `t_base` (`feels = max(HeatIndex(c_to_f(base + m·offset), rh), base + m·offset)`); drive `base(t)`/`m(t)` from `coeffs.nml` via `diurnal_mod` selectors; build scenarios by `work = baseline` (deep copy) then one elemental clamped mutation; assert only the documented pairwise `gap_predawn > gap_afternoon` invariant (NOT "pre-dawn is the global max" — see Pitfall 2).

## Architectural Responsibility Map

This is a single-tier batch CLI; "tiers" map to the project's module layers (ARCHITECTURE.md).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `m(t)` / `base(t)` lookup | Domain (`diurnal_mod`) | Foundation (`coeffs_t` carries values) | Pure selectors over config scalars; no I/O, no state |
| Diurnal threading into feels | Domain (`feels_mod` kernel) | — | Stays `elemental pure`; `m`/`base` are scalar args broadcast over cell arrays |
| Copy-then-mutate scenarios | Application (`scenario_mod`) | Data (`grid_mod` deep-copy) | Orchestration over pure kernels; relies on intrinsic assignment semantics |
| Gap / city-average reductions | Application (`summary_mod`) | — | `sum`/`count` masked reductions; reused by Phase 4 |
| Timestep × scenario driver loop | Driver (`app/main.f90`) | all above | Composition root; owns the minimal console print (D-12) |
| `base_*` / delta config load + validate | Data (`io_mod` + `coeffs.nml`) | — | Follows existing `read_coeffs_nml` fail-loud pattern (GRID-04) |

## Standard Stack

No new dependencies. The entire toolchain is fixed by `CLAUDE.md` and already present/verified.

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| gfortran (GCC) | 16.1.0 (Homebrew) | Compiler, `-std=f2018` | Already installed; F2018 fully supported `[VERIFIED: CLAUDE.md, STACK.md]` |
| fpm | 0.13.0 | Build / test / run | Auto module-order; `fpm test`/`fpm run` `[VERIFIED: STACK.md]` |
| test-drive | 0.6.0 | Unit testing | Already a `[dev-dependencies]` in `fpm.toml`; harness used by all existing tests `[VERIFIED: fpm.toml, test/]` |
| iso_fortran_env | intrinsic | `real64` via `kinds_mod` (`wp`) | Portable kinds `[VERIFIED: src/kinds.f90]` |

### Supporting
None. Standard Fortran intrinsics cover everything Phase 3 needs: `sum`, `count`, `min`, `max`, `merge`, `exp`, masked array reductions `[CITED: ARCHITECTURE.md Anti-Pattern 5]`.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `m` as a required arg to `feels_like_c` | `m` as `optional` with default 1.0 | Optional args in `elemental` procedures are legal but complicate `present()` logic and the snan/init story; a required arg is simpler and the callers must change anyway (driver loops timesteps). **Use required arg.** |
| Lookup-table `m(t)`/`base(t)` | Smooth cosine `m(t)=m0+m1·cos(2π(t−φ)/24)` | Cosine is REFN-03 (deferred to v2 by D-04). **Use lookup.** |
| New thin "feels-from-tadj" function in driver | Thread `m` into existing kernel | A separate function duplicates the offset call + floor logic. **Thread `m` into the one kernel.** |

**Installation:** Nothing to install. `fpm build` / `fpm test` use the existing manifest.

## Package Legitimacy Audit

> Not applicable — this phase installs **no external packages**. The only dependency (`test-drive` v0.6.0) is already pinned in `fpm.toml` and was verified in Phase 2. No registry verification required.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture (data flow for one full run)

```
data/coeffs.nml ──read_coeffs_nml──► coeffs_t {w_*, m_*, base_*, add_trees_delta, concrete_delta, d0, ...}
data/hcmc_districts.csv ──read_grid_csv──► baseline: grid_t (allocate-once)
        │
        ▼  app/main.f90 driver
   for each scenario s in {baseline, add_trees, more_concrete}:        ◄── scenario_mod
        work = baseline                 ! intrinsic assignment = DEEP COPY of cells(:,:)  (D-07)
        call apply_scenario(work, scen) ! ONE elemental clamped mutation (D-06)
        for each timestep it in {morning, afternoon, evening, predawn}: ◄── diurnal_mod
            m_t    = diurnal_m(coeffs, it)        ! 0.5 / 0.3 / 0.8 / 1.0
            base_t = diurnal_base(coeffs, it)     ! 29 / 33 / 30 / 25
            feels(:,:) = feels_like_c(base_t, m_t, work%cells%rh, ...)  ◄── feels_mod (elemental pure)
            gap(it)    = urban_rural_gap(feels, work)                   ◄── summary_mod
            (Phase 4 will fan feels → CSV here)
        deltas vs baseline-scenario's feels at same it  (D-08, SCEN-02)
        │
        ▼  MINIMAL console (D-12): gap-per-timestep line + city-avg-delta-per-scenario line
```

Trace the headline use case: a hot afternoon (`base=33, m=0.3`) yields a **small** urban–rural gap; pre-dawn (`base=25, m=1.0`) yields a **large** gap — the gap grows as you read down the timestep loop. That shape is the teaching payoff.

### Recommended Project Structure (additions only)
```
src/
├── diurnal.f90    # diurnal_mod   — pure selectors diurnal_m / diurnal_base / time_label
├── scenario.f90   # scenario_mod  — type(scenario_t), apply_scenario, build the 3 scenarios
└── summary.f90    # summary_mod   — urban_rural_gap, city_average (masked reductions)
# MODIFIED: src/feels.f90 (+m arg), src/grid.f90 (coeffs_t fields), src/io.f90 (namelist), data/coeffs.nml, app/main.f90
test/
├── test_diurnal.f90    # m/base selector values + m=1 regression-equals-Phase-2
├── test_scenario.f90   # immutability, one-driver, clamp, delta-sign, deep-copy independence
└── test_gap.f90        # HARD gap_predawn>gap_afternoon, night-sanity, SOFT magnitude warn
```
Build order (extends ARCHITECTURE.md topo order): `diurnal.f90` after `kinds`/`grid`; `summary.f90` after `grid`+`feels`; `scenario.f90` after `grid`+`feels`+`diurnal`. fpm resolves this automatically from `use` statements — no manual ordering.

### Pattern 1: Thread `m` into the elemental kernel (the integration point)
**What:** Add one scalar `m` argument scaling the offset; everything else unchanged.
**When to use:** This is THE Phase-3 change to `feels_mod`.
**Example:** see Code Examples §1.

### Pattern 2: Copy-then-mutate via intrinsic assignment
**What:** `work = baseline` deep-copies the allocatable `cells(:,:)` (and each cell's allocatable `name`). Mutate `work` only.
**When to use:** Every scenario. Guarantees SCEN-01 immutability for free.
**Example:** see Code Examples §3.

### Pattern 3: Masked reductions for the gap (no manual loops)
**What:** `sum(feels, mask=urban_occ)/real(count(urban_occ),wp) − sum(feels, mask=rural_occ)/real(count(rural_occ),wp)`.
**When to use:** Gap (D-09) and city-average delta (D-08). Reused verbatim by Phase 4.
**Example:** see Code Examples §4.

### Anti-Patterns to Avoid
- **Asserting "pre-dawn is the global maximum gap."** It is not, with these defaults — early-evening (`base=30, m=0.8`) can numerically edge pre-dawn because the warmer base puts more cells into the amplifying heat-index branch (verified: evening +6.1 vs predawn +5.2 on the full urban set). The locked HARD test is **only** the pairwise `gap_predawn > gap_afternoon` (D-10). Don't over-constrain.
- **Re-`allocate(work%cells(...))` inside the scenario/timestep loop.** Double-allocation runtime error (A8). Let intrinsic assignment allocate, or allocate `work` once before the loop.
- **Declaration-initialised accumulators in per-timestep/scenario routines** (`real(wp) :: acc = 0.0_wp`) — implies `save`, not reset between calls (A4). Initialise in the executable body.
- **Integer division in the gap/average** — `sum(...)/count(...)` is real/integer; wrap the count: `real(count(mask), wp)` (A2).
- **A second post-hoc offset or per-scenario humidity tweak** — keep the single Phase-2 budget; only temperature base and land-cover drivers move (B3, Deferred).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deep-copy the grid for a scenario | Manual per-field copy loop | `work = baseline` (intrinsic assignment) | Fortran deep-copies allocatable components automatically, incl. `name` `[CITED: ARCHITECTURE.md Pattern 4; CONTEXT D-07]` |
| Urban/rural mean | Nested `do` loops with counters | `sum(feels, mask)/real(count(mask),wp)` | Intrinsics; vectorized, fewer off-by-one/uninit bugs `[CITED: ARCHITECTURE.md Anti-Pattern 5]` |
| Clamp a driver to [0,1] | `if` ladders | `min(1.0_wp, max(0.0_wp, x))`, elemental over the array | One elemental expression broadcasts over `cells(:,:)` |
| Broadcast feels over the grid at a timestep | Explicit `do i; do j` calling scalar feels | Call `elemental feels_like_c` with array args + scalar `m`,`base` | Elemental broadcasts; scalar/array mix is legal `[CITED: ARCHITECTURE.md Pattern 3]` |
| Time-of-day curve | Hand-rolled cosine/interp | 4-entry `select case` lookup over `coeffs%m_*`/`base_*` | D-04 locks lookup; cosine is deferred REFN-03 |

**Key insight:** Phase 3 adds almost no arithmetic — it adds *orchestration*. Every reduction and copy it needs is a single intrinsic. The risk is not code volume; it's getting the diurnal direction and the apples-to-apples discipline right, both of which are guarded by tests.

## Common Pitfalls

### Pitfall 1: Diurnal UHI backwards (THE make-or-break, PITFALLS B2)
**What goes wrong:** Making the gap peak at mid-afternoon (peak sun) instead of pre-dawn inverts the project's core value.
**Why it happens:** Confusing "hottest absolute temperature" (afternoon) with "largest urban–rural difference" (night).
**How to avoid:** `m` smallest at afternoon (0.3), largest pre-dawn (1.0) — already in `coeffs.nml`. The HARD test `gap_predawn > gap_afternoon` locks it. **Verified numerically** (Phase-2 weights, urban-core archetype set): afternoon `+0.7 °C`, pre-dawn `+7.1 °C` — holds with ~6 °C margin `[VERIFIED: worked calc this session]`.
**Warning signs:** gap maxes at afternoon timestep; night map shows urban≈rural; test fails or passes only by a hair.

### Pitfall 2: `base(t)` does NOT exactly cancel in the gap when the heat-index branch is active
**What goes wrong:** D-02 says `base(t)` cancels in the gap. That is **exactly true only in the linear floor regime** (`feels = t_adj`): `(base + m·off_u) − (base + m·off_r) = m·(off_u − off_r)`. When `t_adj ≥ 80 °F`, `feels = HeatIndex(...)` is nonlinear and amplifies (dHI/dT > 1), so a hotter `base` *inflates* the gap for a given `m`. This is why early-evening gap can exceed pre-dawn gap (verified), and why the invariant is a margin, not an identity.
**Why it happens:** Treating the conceptual "offset carries the gap" claim as an exact algebraic cancellation through the nonlinear heat index.
**How to avoid:** Keep the 3.3× `m` ratio (predawn/afternoon) — it dominates the HI amplification at these bases. Don't push `base_afternoon` far above ~33 °C (more amplification narrows the safety margin). Assert only the pairwise pre-dawn>afternoon invariant. SOFT-print the magnitude so calibration is guided (STATE blocker: land peak night gap in 3–8 °C).
**Warning signs:** afternoon gap creeping positive and large as you raise `base_afternoon`; the HARD margin shrinking when weights/bases are tuned.

### Pitfall 3: Scenario not apples-to-apples (PITFALLS B5)
**What goes wrong:** Changing more than one driver, or comparing a scenario at one timestep to baseline at another, makes the reported "+trees → −Y °C" meaningless.
**How to avoid:** Exactly one non-zero delta per `scenario_t` (D-06); compute `feels_scenario − feels_baseline` at the *same* `it` with the *same* weather (D-08). Immutable baseline (copy-then-mutate) guarantees the shared reference. Test: add_trees changes `tree` only (building untouched) and lowers city-average feels; more_concrete changes `building` only and raises it.

### Pitfall 4: Allocatable lifecycle in the loops (PITFALLS A8) + save-trap (A4)
**What goes wrong:** Re-allocating `work%cells` each scenario → "already allocated" runtime error or leak; declaration-init accumulators silently retain state across timestep calls.
**How to avoid:** Allocate `work` once (or rely on same-shape intrinsic assignment, which does not reallocate); initialise all accumulators in the executable body, never in the declaration. Run the suite under `-fcheck=all -finit-real=snan` (see Pitfall 5).

### Pitfall 5: Strict dev flags must come via `fpm test --flag`, NOT the manifest
**What goes wrong:** `fpm` 0.13.0 **rejects** `[profiles.*.gfortran]` blocks in `fpm.toml` (project MEMORY note; STACK.md). Putting strict flags there breaks the build.
**How to avoid:** Pass strict flags on the CLI:
```bash
fpm test --flag "-std=f2018 -fcheck=all -Wall -Wextra -fimplicit-none -finit-real=snan -finit-integer=-99999"
```
`-finit-real=snan` interacts with the masked reductions: compute `feels` for **all** cells elementally (every element assigned — no snan), then mask in the reduction. Do not leave unoccupied-cell feels uninitialised. `-ffpe-trap` is safe here (no `sqrt` of negatives — the RH<13 % heat-index branch is never hit at HCMC 70–88 % RH; `exp(−water_km/d0)` is well-defined). Release build stays `-O2` (no `-ffast-math`).

## Runtime State Inventory

> Not applicable — Phase 3 is a greenfield additive phase (new modules + new config keys + one kernel-signature change). No rename/refactor/migration, no stored data, no live-service config, no OS-registered state. **Verified:** the only "state" is config values in `data/coeffs.nml` (additive new keys) and source — no datastore, no external service, no secrets.

## Code Examples

> All examples follow the established project conventions (`private` module, explicit `public`, `use ..., only:`, `wp` literals, `elemental pure` kernels). Verified against `src/feels.f90`, `src/grid.f90`, `test/test_ordering.f90`.

### §1 — Threaded kernel (`src/feels.f90`, the one signature change)
```fortran
! Source: derived from existing src/feels.f90 (Phase 2) + CONTEXT D-01
elemental pure function feels_like_c(t_base, m, rh, building, tree, water_km, is_urban, &
                                     w_build, w_urban, w_tree, w_water, d0) result(feels_c)
    real(wp), intent(in) :: t_base, m, rh, building, tree, water_km
    logical,  intent(in) :: is_urban
    real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
    real(wp) :: feels_c, t_adj_c, hi_f
    t_adj_c = t_base + m * uhi_offset(building, tree, water_km, is_urban, &   ! m·ΔT_UHI
                                      w_build, w_urban, w_tree, w_water, d0)
    hi_f    = heat_index_f(c_to_f(t_adj_c), rh)
    feels_c = max(f_to_c(hi_f), t_adj_c)                                       ! floor (Phase 2 D-09)
end function feels_like_c
```
**Blast radius of this signature change (2 call sites — update both):**
- `app/main.f90:39` — currently `feels_like_c(coeffs%t_base, grid%cells%rh, ...)`. Phase 3 replaces this single call with the timestep loop, passing `base_t, m_t` per `it`.
- `test/test_ordering.f90` — ~15 calls (lines 40–53, 81–101, 118). Insert `1.0_wp` as the second arg (`m=1` reproduces Phase-2 behaviour). The Phase-2 ordering/monotonicity/floor assertions stay valid at `m=1`. *(CLAUDE.md mandates impact analysis before editing a symbol; the two call sites above are the complete caller set — confirmed by reading both files.)*

### §2 — Diurnal selectors (`src/diurnal.f90`)
```fortran
module diurnal_mod
    use kinds_mod, only: wp
    use grid_mod,  only: coeffs_t
    implicit none
    private
    public :: NT, T_MORNING, T_AFTERNOON, T_EVENING, T_PREDAWN, diurnal_m, diurnal_base, time_label
    integer, parameter :: NT = 4
    integer, parameter :: T_MORNING = 1, T_AFTERNOON = 2, T_EVENING = 3, T_PREDAWN = 4
contains
    pure function diurnal_m(c, it) result(m)
        type(coeffs_t), intent(in) :: c
        integer,        intent(in) :: it
        real(wp) :: m
        select case (it)
        case (T_MORNING);   m = c%m_morning
        case (T_AFTERNOON); m = c%m_afternoon
        case (T_EVENING);   m = c%m_evening
        case default;       m = c%m_predawn
        end select
    end function diurnal_m
    ! diurnal_base mirrors this over c%base_morning/afternoon/evening/predawn
    pure function time_label(it) result(s)
        integer, intent(in) :: it
        character(len=:), allocatable :: s
        select case (it)
        case (T_MORNING);   s = 'morning'
        case (T_AFTERNOON); s = 'afternoon'
        case (T_EVENING);   s = 'evening'
        case default;       s = 'predawn'
        end select
    end function time_label
end module diurnal_mod
```

### §3 — Scenario engine (`src/scenario.f90`)
```fortran
type, public :: scenario_t
    character(len=:), allocatable :: label
    real(wp) :: tree_delta     = 0.0_wp   ! exactly one delta non-zero per scenario (D-06)
    real(wp) :: building_delta = 0.0_wp
end type scenario_t

subroutine apply_scenario(work, scen)        ! work is already a deep copy of baseline
    type(grid_t),     intent(inout) :: work
    type(scenario_t), intent(in)    :: scen
    ! elemental clamp to [0,1] over the whole grid; one driver moves
    work%cells%tree     = min(1.0_wp, max(0.0_wp, work%cells%tree     + scen%tree_delta))
    work%cells%building = min(1.0_wp, max(0.0_wp, work%cells%building + scen%building_delta))
end subroutine apply_scenario

! Driver usage — deep copy then mutate (baseline never touched, SCEN-01):
work = baseline                ! intrinsic assignment: deep-copies cells(:,:) and each name
call apply_scenario(work, scen)
```
Build the three scenarios in code (D-05): `baseline` (both deltas 0), `add_trees` (`tree_delta = coeffs%add_trees_delta`), `more_concrete` (`building_delta = coeffs%concrete_delta`).

### §4 — Gap + city-average reductions (`src/summary.f90`)
```fortran
pure function urban_rural_gap(feels, g) result(gap)
    real(wp),     intent(in) :: feels(:,:)
    type(grid_t), intent(in) :: g
    real(wp) :: gap
    logical  :: mu(size(feels,1), size(feels,2)), mr(size(feels,1), size(feels,2))
    mu = g%cells%is_urban        .and. g%cells%occupied
    mr = (.not. g%cells%is_urban) .and. g%cells%occupied
    gap = sum(feels, mask=mu) / real(count(mu), wp) &      ! real() guards integer division (A2)
        - sum(feels, mask=mr) / real(count(mr), wp)
end function urban_rural_gap
! city_average(feels, g) = sum(feels, mask=occupied)/real(count(occupied),wp)
! per-cell scenario delta = feels_scenario - feels_baseline   (elementwise, same it)
```
(Guard `count(mu) > 0` / `count(mr) > 0` against a degenerate grid before dividing.)

### §5 — `data/coeffs.nml` additions (and matching `io_mod`/`coeffs_t`)
```fortran
&coeffs
  ... existing w_*, m_*, t_base, rh_base, d0, nx, ny ...
  base_morning   = 29.0      ! m=0.5
  base_afternoon = 33.0      ! m=0.3   hottest absolute, smallest gap
  base_evening   = 30.0      ! m=0.8
  base_predawn   = 25.0      ! m=1.0   coolest, largest gap
  add_trees_delta = 0.2
  concrete_delta  = 0.2
/
```
Add the six fields to `type(coeffs_t)` (`src/grid.f90`), to the `namelist /coeffs/` + defaults + assignment in `read_coeffs_nml` (`src/io.f90`), following the existing pattern. Add load-time validation: each `base_*` within `[T_MIN, T_MAX]` (10–50 °C); each delta in `(0.0, 1.0]`. Fail loud with the existing `stat`/`msg` convention.

### §6 — In-test gap invariant (`test/test_gap.f90`, mirrors test_ordering.f90 style)
```fortran
! Reuse Phase-2 archetype params; urban-core set gives a clean positive gap both timesteps.
! Recommended sets (VERIFIED numerically this session):
!   urban = {industrial(0.92,0.03,4.0,T,72), D1(0.85,0.10,1.0,T,75), D5(0.82,0.08,1.5,T,77)}
!   rural = {cangio(0.05,0.85,0.2,F,88), cuchi(0.15,0.55,9.0,F,82), nhabe(0.30,0.45,0.5,F,83)}
! gap = mean(feels over urban) - mean(feels over rural), per timestep.
gap_afternoon = gap_at(33.0_wp, 0.3_wp)   ! ≈ +0.7 C
gap_predawn   = gap_at(25.0_wp, 1.0_wp)   ! ≈ +7.1 C
call check(error, gap_predawn > gap_afternoon)        ! HARD (D-10)
! night-sanity (re-verify HEAT-02): pre-dawn rural cell ≈ near air temp, no nonsense
feels_cangio = feels_like_c(25.0_wp, 1.0_wp, 88.0_wp, 0.05_wp, 0.85_wp, 0.2_wp, .false., &
                            3.0_wp, 1.0_wp, 2.5_wp, 2.0_wp, 2.5_wp)  ! ≈ 21.4 C (floor active)
call check(error, feels_cangio >= 21.0_wp .and. feels_cangio <= 26.0_wp)
! SOFT magnitude: warn-not-fail
if (.not. (gap_predawn >= 3.0_wp .and. gap_predawn <= 8.0_wp)) &
    write(error_unit,'(A,F0.2,A)') 'WARN night gap = ', gap_predawn, ' C (expect ~3-8 C)'
```

## State of the Art

| Old Approach (Phase 2) | Current Approach (Phase 3) | When Changed | Impact |
|------------------------|----------------------------|--------------|--------|
| `feels_like_c(t_base, rh, ...)`, offset at full strength (`m=1`) | `feels_like_c(t_base, m, rh, ...)`, offset scaled by `m(t)` | This phase | 2 call sites update; Phase-2 tests pass `m=1` |
| Single baseline time, one grid pass | 4 timesteps × 3 scenarios | This phase | Driver becomes nested loops over pure kernels |
| `coeffs_t` carries dormant `m_*` | `m_*` consumed; parallel `base_*` + deltas added | This phase | `coeffs.nml`/`io_mod`/`coeffs_t` extended |

**Deprecated/outdated:** nothing removed — Phase 3 is purely additive over Phase 2.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Default `base_*` = 29/33/30/25 °C | Code Examples §5, Summary | LOW — within cited HCMC ranges; tunable via config (GRID-04). Wrong values only shift magnitudes, not the invariant direction. |
| A2 | `add_trees_delta = concrete_delta = 0.2` | §5, Default values | LOW — tunable; 0.2 moves city-avg ~0.5–0.6 °C/cell pre-dawn without saturating clamps. Range 0.15–0.25 all fine. |
| A3 | Night gap lands in 3–8 °C with these defaults | Summary, Pitfall 2 | MEDIUM — verified ~+5 °C (full set) / +7 °C (core set) by worked calc, but the SOFT check + STATE blocker exist precisely to confirm/tune at execution. Does not gate the build. |
| A4 | Recommended in-test archetype sets (urban core vs rural) | Code Examples §6 | LOW — derived from Phase-2 archetypes + verified numerically this session; planner may pick any set that keeps the margin. |
| A5 | `m` added as the 2nd positional arg of `feels_like_c` | §1, Discretion | LOW — Claude's-discretion API shape; any signature keeping the kernel `elemental pure` satisfies D-01. Position chosen for "two diurnal knobs together." |

**Note:** the diurnal-direction physics and HCMC baseline ranges are `[CITED: FEATURES.md, PITFALLS.md]` (HIGH), not assumed. The numeric gap figures (+0.7 / +7.1 °C) are `[VERIFIED: worked calculation this session against the real Phase-2 weights]` and should be re-confirmed by the actual `test_gap.f90` run.

## Open Questions (RESOLVED)

Both items are Claude's-discretion narrative/format choices (not technical unknowns); each carries an adopted recommendation, so execution is fully specified.

1. **Does early-evening gap exceeding pre-dawn gap matter for the narrative?**
   - What we know: with defaults, evening (+6.1) can slightly exceed predawn (+5.2) on the full urban set, because the warmer evening base activates more heat-index amplification.
   - What's unclear: whether the learner-facing story wants pre-dawn to be the strict peak.
   - **RESOLVED:** keep the HARD test pairwise (`predawn > afternoon`) per D-10; treat "night ≫ afternoon" as the story. If a strict pre-dawn peak is later desired, that's a calibration/REFN-03 (cosine) concern, not a v1 blocker. Adopted by 03-03 (asserts only the pairwise invariant, explicitly forbids a global-max claim).

2. **Exact minimal console format (D-12).**
   - What we know: one gap line per timestep + one delta line per scenario.
   - **RESOLVED** (Claude's discretion): `predawn: gap = 5.20 C` per timestep; `add_trees: city-avg dT = -0.51 C @ predawn` per scenario. Keep `feels(:,:)` reachable so Phase 4 wires CSV/summary without rework. Use width-free `F0.2`/`g0` (pre-empts A9 `*****`). Adopted by 03-02/03-03 console output.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gfortran | compile/test | ✓ | GCC 16.1.0 | — |
| fpm | build/test/run | ✓ | 0.13.0 | — |
| test-drive | unit tests | ✓ (pinned in `fpm.toml`, fetched by fpm) | 0.6.0 | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none. Strict dev flags are passed via `fpm test --flag "..."` (NOT the manifest — fpm 0.13.0 rejects `[profiles.*.gfortran]`).

## Security Domain

> `security_enforcement: true`, ASVS L1. This is an offline batch scientific tool: no network, no auth, no sessions, no untrusted remote input. Only V5 (input validation) is materially applicable.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no users/auth) |
| V3 Session Management | no | — (no sessions) |
| V4 Access Control | no | — (single local CLI) |
| V5 Input Validation | yes | Load-time range validation of the new `base_*` (within `[T_MIN,T_MAX]`) and deltas (`(0,1]`), via the existing fail-loud `read_coeffs_nml` `stat`/`msg` pattern (A10/B4). |
| V6 Cryptography | no | — (no secrets/crypto) |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed/out-of-range config value silently mis-seeds the model | Tampering (data integrity) | Validate every new namelist field at load; reject with line/context; never run on partial data (existing io_mod pattern) |
| Uninitialised reads / NaN propagation into the gap | Information disclosure (wrong science) | `-finit-real=snan -fcheck=all` in dev; compute feels for all cells before masking |

(No injection/SSRF/secret-handling surface exists in this phase.)

## Sources

### Primary (HIGH confidence) — curated project research, read this session
- `.planning/research/FEATURES.md` §3 Diurnal signature, §What-if scenario comparison, §HCMC Baselines (m(t) values, 24→33 °C range, 70–85 % RH, 3–8 °C night UHI)
- `.planning/research/PITFALLS.md` §B2 (diurnal backwards), §B5 (apples-to-apples), §A8 (allocatable lifecycle), §A4 (save-init trap), §A2 (integer division), §A9 (output formatting context)
- `.planning/research/ARCHITECTURE.md` (module build order, Pattern 3 elemental broadcast, Pattern 4 copy-then-mutate, Anti-Pattern 5 intrinsic reductions)
- `.planning/research/STACK.md` + project MEMORY (fpm 0.13.0 rejects `[profiles.*.gfortran]`; strict flags via `--flag`)
- Phase-2 source read directly: `src/feels.f90`, `src/uhi.f90`, `src/grid.f90`, `src/heat_index.f90`, `src/constants.f90`, `src/io.f90`, `app/main.f90`, `data/coeffs.nml`, `data/hcmc_districts.csv`, `test/test_ordering.f90`, `test/test_uhi.f90`, `fpm.toml`
- `02-CONTEXT.md` (feels pipeline contract: D-01 hybrid base, D-03 single budget, D-09 floor, D-10/D-11 in-test archetypes + rank/sign testing)

### Secondary (verified this session)
- Worked numerical check (Python reproduction of the exact Fortran heat-index + offset math) confirming `gap_predawn=+7.1 °C` vs `gap_afternoon=+0.7 °C` (urban-core set) and `≈+5.2 / −0.16 °C` (full set incl. park); pre-dawn Can Gio feels ≈ 21.4 °C (floor active).

### Tertiary (LOW confidence)
- None. No web research performed or needed — all inputs are curated HIGH-confidence research and the live Phase-2 codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fixed by CLAUDE.md/STACK.md; nothing new to install; verified against `fpm.toml`.
- Architecture / threading: HIGH — direct extension of read Phase-2 source; signature change and callers identified precisely.
- Pitfalls / invariant: HIGH — B2/B5/A8/A4 cited; the make-or-break gap direction verified numerically with margin.
- Default values / magnitudes: MEDIUM — within cited HCMC ranges and numerically checked, but tunable and confirmed by the SOFT check at execution (STATE blocker).

**Research date:** 2026-06-29
**Valid until:** stable indefinitely (curated science + pinned toolchain); re-verify only if Phase-2 weights, `coeffs.nml` schema, or the heat-index branch change.
</content>
</invoke>
