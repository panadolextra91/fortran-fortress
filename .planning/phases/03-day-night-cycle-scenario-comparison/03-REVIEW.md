---
phase: 03-day-night-cycle-scenario-comparison
reviewed: 2026-06-29T08:43:16Z
depth: deep
files_reviewed: 13
files_reviewed_list:
  - app/main.f90
  - data/coeffs.nml
  - src/diurnal.f90
  - src/feels.f90
  - src/grid.f90
  - src/io.f90
  - src/scenario.f90
  - src/summary.f90
  - test/fixtures/coeffs_bad_base.nml
  - test/test_diurnal.f90
  - test/test_gap.f90
  - test/test_io.f90
  - test/test_ordering.f90
  - test/test_scenario.f90
findings:
  critical: 0
  warning: 5
  info: 5
  rejected: 1
  total: 10
status: resolved
resolution: >-
  Round 2 (2026-06-29): all 10 validated findings fixed by Antigravity in 10 atomic
  commits (aff6aff..1fea101). Verified by orchestrator (Claude) — clean build and
  30/30 tests pass under strict flags; the core invariant is confirmed unchanged by a
  live run (gaps +4.01/+0.70/+7.93/+6.35 °C; add_trees cools, more_concrete warms);
  new real-grid gap test + m_*/nx-ny/empty-file validation tests added. The two
  fix-suggestion traps were correctly avoided (WR-02 does not assert predawn-max;
  IN-03 uses a pure-safe NaN sentinel, not error stop). WR-07 correctly not actioned.
  Remaining items are cosmetic nits only (non-blocking).
adjudication: >-
  Orchestrator (Claude) verified every finding against the codebase, git history,
  and a live build + run under strict flags (-std=f2018 -fcheck=all
  -ffpe-trap=invalid,zero,overflow -finit-real=snan). All tests pass (exit 0) and
  the core invariant (urban>rural at all 4 timesteps, predawn gap persists) is
  confirmed by an actual run. Two agent findings were corrected: WR-07 REJECTED
  (hallucinated "remove buildings" brief — Phase 3 spec says "more concrete" in
  ROADMAP:127 and CONTEXT D-05/D-06; "remove buildings" appears nowhere in
  .planning/). WR-01 RECLASSIFIED Warning -> Info (per-cell t_air was never used in
  Phase 2 either, so it is not a Phase 3 regression; a uniform base temperature is
  the intended design per the "same baseline weather" core value — feeding per-cell
  t_air would double-count the very effect the model isolates).
---

# Phase 3: Code Review Report

**Reviewed:** 2026-06-29T08:43:16Z
**Depth:** deep
**Files Reviewed:** 13
**Status:** resolved (round 2 — all 10 findings fixed & verified; WR-07 rejected)

## Summary

Phase 3 adds the diurnal cycle (`diurnal_mod`), scenario comparison (`scenario_mod`),
and the urban–rural gap (`summary_mod`), threading a per-timestep multiplier `m` into
`feels_like_c`. I traced every domain invariant the project's core value depends on:

- **UHI sign:** `uhi_offset = w_build*building + w_urban*U − w_tree*tree − w_water*exp(−water_km/d0)`.
  Signs are correct — building/urban raise the offset, trees/water lower it.
- **`m` threading:** `t_adj = base + m*offset`. Predawn `m=1.0` (max) and afternoon `m=0.3`
  (min) correctly make the night gap the largest. No inversion.
- **Floor:** `feels = max(f_to_c(hi), t_adj)` is correct; heat index never cools below dry temp.
- **Scenario deltas:** `add_trees` (+tree) lowers offset (cools); `more_concrete` (+building)
  raises offset (warms). Internally sign-consistent.
- **Gap:** `gap = u_mean − r_mean` — positive means urban hotter. Correct.

**There is no sign-error / min-max inversion in the code itself — the qualitative physics
is wired correctly.** This was further confirmed by a live build + run: all tests pass
under strict flags and the actual run gives a positive urban−rural gap at every timestep
(morning +4.01, afternoon +0.70, evening +7.93, predawn +6.35 °C), with `add_trees`
cooling and `more_concrete` warming the city. The defects below are (a) unvalidated config
that could silently invert the core invariant, (b) untested invariants under the
*heterogeneous humidity* that actually exists in the real grid data, and (c) fragile
coupling and dead code/config.

**The single most important finding is WR-02** — the urban>rural gap is only ever tested
with uniform humidity, while the real data gives rural cells *higher* RH, and the live
afternoon gap (+0.70 °C) is razor-thin with no test guarding `gap > 0` on the real grid.
**WR-03** (unvalidated `m_*`) is the closest config path to silently inverting the core
invariant.

> **Orchestrator adjudication (Claude):** Two findings were corrected after verification —
> see the disposition banners on **WR-01** (reclassified Warning → Info; not a regression,
> uniform base is intentional) and **WR-07** (rejected; the "remove buildings" brief is a
> hallucination — the spec says "more concrete"). Do **not** action WR-07.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Per-cell air temperature is loaded and validated but never used in the feels path  *(reclassified → Info)*

> **Disposition (orchestrator, Claude): RECLASSIFIED Warning → Info — NOT a regression.**
> Verified against git: Phase 2's `main` already passed a **uniform** `coeffs%t_base`
> (28.0) to `feels_like_c` and **never** used per-cell `cell%t_air`. So Phase 3 did not
> regress anything — `t_air` has been display-only since it was introduced. Moreover, a
> uniform base temperature is the **scientifically intended design**: the project's core
> value is the gap "for the **same baseline weather**", which deliberately isolates the
> land-cover UHI effect. Feeding per-cell `t_air` (where urban is already hotter) would
> **double-count** the very effect the model exists to demonstrate. This is therefore a
> *clarity* issue (a loaded, range-validated CSV column that has no effect on output will
> confuse a learner who edits it), **not a correctness bug.** Closely related to IN-02.

**File:** `app/main.f90:82-89`, `src/io.f90:208`, `data/hcmc_districts.csv:2-15`
**Issue:** `read_grid_csv` parses, range-checks (`T_MIN..T_MAX`), and stores `cell%t_air`
for every district, but no feels computation ever reads it — the temperature argument is
always the diurnal base (`base_t = diurnal_base(coeffs, it)`):

```fortran
feels_val = feels_like_c(base_t, m_t, work%cells(i,j)%rh, ...)
```

The CSV's 5.5 °C `t_air` spread (Thu Duc Industrial 34.5 vs Can Gio 29.0) contributes 0 to
the heat map *by design* — all spatial variation comes from the building/tree/water/urban
offset. The problem is only that the dead column **looks** load-bearing.
**Fix (low priority, clarity only):** Either (a) document in `CONTEXT` that the diurnal
base intentionally supersedes per-cell `t_air` and keep the column as a Phase-4 CSV
reference field, or (b) drop `t_air` from the seed CSV + validation path. Do **not** wire
`t_air` into the feels base — that would undermine the "same baseline weather" experiment.

### WR-02: Urban>rural gap invariant is only tested with uniform humidity; real grid gives rural cells higher RH

**File:** `test/test_gap.f90:29-93`, `test/test_ordering.f90:37`, `data/hcmc_districts.csv:12-15`
**Issue:** Every ordering/gap test holds RH constant (`rh = 75/78` for all cells). But the
actual data gives rural/green cells *higher* humidity than the urban core — Can Gio `88`,
Nha Be `83`, Cu Chi `82` vs urban `72–80`. `heat_index_f` is monotonically increasing in
RH, so at hot timesteps a humid rural cell can gain more from the heat-index term than a
hot-but-drier urban cell, narrowing — and potentially inverting — the urban−rural gap.
Worked afternoon estimate (base=33, m=0.3): industrial `t_adj≈34.1 °C/93.4 °F @ RH72`,
Can Gio `t_adj≈30.8 °C/87.4 °F @ RH88`; the Rothfusz term partly closes that ~6 °F dry
gap. No test asserts `gap > 0` on the *real* grid at *any* timestep, so a humidity-driven
inversion of the project's central invariant ("dense treeless urban MUST be hotter than
green/waterfront") would ship undetected.
**Fix:** Add a test that loads `data/hcmc_districts.csv` and asserts
`urban_rural_gap(feels, g) > 0` for all four timesteps (and that the predawn gap is the
largest). Use cells with *differing* RH so the heat-index humidity confound is exercised.

### WR-03: Diurnal `m_*` multipliers are never validated — a negative value silently inverts the UHI

**File:** `src/io.f90:71-91` (validation block), `data/coeffs.nml:6-9`
**Issue:** `read_coeffs_nml` validates `d0 > 0`, `base_*` within `T_MIN..T_MAX`, and the
two scenario deltas, but performs **no check on `m_morning/m_afternoon/m_evening/m_predawn`**.
Because `t_adj = base + m*offset`, a negative `m_*` flips the sign of the entire offset:
urban cells become *cooler* than rural for that timestep — a direct inversion of the core
value — with no error and a clean run. The defaults are fine, but the model is explicitly
config-driven so external tuners can introduce this silently.
**Fix:** After the namelist read, reject non-physical multipliers:
```fortran
if (m_morning < 0.0_wp .or. m_afternoon < 0.0_wp .or. &
    m_evening < 0.0_wp .or. m_predawn < 0.0_wp) then
    stat = 1; msg = trim(path) // ': m_* must be >= 0'; return
end if
```

### WR-04: `nx`/`ny` not validated positive; default 0 produces a zero-size grid and a misleading error

**File:** `src/io.f90:51-52, 110-111`, `app/main.f90:34`
**Issue:** `nx`/`ny` default to `0` and are passed straight to `read_grid_csv` →
`allocate_grid(g, 0, 0)`, allocating a zero-extent `cells` array. If a config omits
`nx`/`ny`, the first data row fails with `'i out of range'` (because `ii > nx = 0`),
pointing the user at the data file when the real fault is missing/zero grid dimensions.
**Fix:** Validate in `read_coeffs_nml` before returning:
```fortran
if (nx < 1 .or. ny < 1) then
    stat = 1; msg = trim(path) // ': nx and ny must be >= 1'; return
end if
```

### WR-05: Empty or header-only grid file returns success (`stat = 0`) with an empty grid

**File:** `src/io.f90:140-144, 147-217`
**Issue:** If the header read fails (empty file) the routine `close`s and `return`s with
`stat` still `0`. Likewise a file with only a header produces `g%ndist = 0` and `stat = 0`.
`main` then runs over zero districts, prints an empty layout, and `urban_rural_gap` returns
`0.0` — a silent no-op simulation that looks like success.
**Fix:** Treat an unreadable header and a zero-district result as errors:
```fortran
if (ios /= 0) then
    stat = 1; msg = trim(path) // ': empty or unreadable (no header)'; close(u); return
end if
...
if (g%ndist == 0) then
    stat = 1; msg = trim(path) // ': no district rows'; close(u); return
end if
```

### WR-06: Baseline capture keyed on `iscen == 1` magic — fragile coupling with an uninitialized-read latent bug

**File:** `app/main.f90:64-79, 91, 95`
**Issue:** `feels_baseline` is populated *only* when `iscen == 1` (line 91) and then
subtracted for every scenario (line 95). Correctness silently depends on `scens(1)` being
the zero-delta baseline **and** being iterated first. Reorder the `scens` array, or insert
a scenario at index 1, and `feels_baseline` is read before assignment → garbage `delta`
(NaN under `-finit-real=snan`/`-ffpe-trap`). The intent ("this is the baseline") is encoded
as a positional literal, not a property of the scenario.
**Fix:** Drive baseline capture off the scenario's own definition, not its index — e.g.
detect zero deltas (`scen%tree_delta == 0 .and. scen%building_delta == 0`) or add an
explicit `is_baseline` flag to `scenario_t`, and assert exactly one baseline exists before
the timestep loop.

### WR-07: ~~`more_concrete` diverges from the spec's "remove buildings" scenario~~  *(REJECTED)*

> **Disposition (orchestrator, Claude): REJECTED — invalid finding, do NOT action.**
> The premise is a hallucination. The string **"remove buildings" appears nowhere in
> `.planning/`** (only inside this review). The Phase 3 spec explicitly requires
> **"more concrete"**, not building removal:
> - `ROADMAP.md:127` — *"a baseline plus at least one 'add trees' and one 'more concrete' scenario"*
> - `CONTEXT.md` **D-05/D-06** — the two required scenarios are *"add trees"* and *"more concrete"* (`building += concrete_delta`).
>
> The shipped `add_trees` + `more_concrete` pair **matches the spec exactly.** There is no
> cooling-scenario requirement to violate. **Do not** add a "remove buildings" scenario and
> **do not** relax the validator to accept negative deltas on the basis of this finding —
> that would itself contradict the spec.
>
> *Surviving sub-note (Info, optional):* the delta validator (`io.f90:86-91`) intentionally
> requires positive deltas, which is correct here since the spec treats deltas as positive
> magnitudes. If arbitrary cooling scenarios are ever desired in a **future** milestone,
> revisit the validator then — out of scope for Phase 3.

## Info

### IN-01: `city_average` is exported and imported but never called; `main` duplicates its body inline

**File:** `src/summary.f90:6, 31-41`, `app/main.f90:97-101`, `test/test_gap.f90:6`
**Issue:** `city_average` is public, imported by `test_gap` (line 6), but never invoked.
`main` re-implements the identical occupied-mask average inline (lines 97-101) instead of
calling it. Dead export + duplicated logic that can drift.
**Fix:** Replace the inline block in `main` with `avg_delta = city_average(delta, work)`
(it already guards the empty-grid case), or drop the unused export and import.

### IN-02: `coeffs%t_base` and `coeffs%rh_base` are read and stored but never used or validated

**File:** `src/io.f90:107-108`, `src/grid.f90:28`, `data/coeffs.nml:16-17`
**Issue:** Both fields are parsed into `coeffs_t` but no consumer references them (the feels
path uses diurnal base + per-cell RH). They are also exempt from range validation, so any
value passes. Dead configuration is misleading — a tuner who edits `rh_base` sees no effect.
**Fix:** Remove the unused fields from `coeffs_t`/the namelist, or wire `t_base` into the
diurnal anchor (see WR-01) and validate `rh_base` against `RH_MIN..RH_MAX`.

### IN-03: Diurnal selectors map any out-of-range `it` to predawn via `case default`

**File:** `src/diurnal.f90:27-28, 44-45, 60-61`
**Issue:** `diurnal_m`, `diurnal_base`, and `time_label` use `case default` for `T_PREDAWN`,
so an invalid index (0, 5, …) silently returns predawn values instead of failing. Safe today
(loops are bounded `1..NT`), but it masks future indexing bugs.
**Fix:** Make predawn an explicit `case (T_PREDAWN)` and add `case default` that does
`error stop 'invalid timestep'` (or returns a sentinel), so misuse surfaces immediately.

### IN-04: Field-count error message embeds trailing spaces from a fixed-length `int2str`

**File:** `src/io.f90:157, 229-234`
**Issue:** `int2str` returns `character(len=32)`; even after `trim(adjustl())` the result is
re-padded to 32 chars, so `'expected 9 fields, got ' // int2str(nf)` carries trailing
spaces in the message. Cosmetic, but messages are asserted on elsewhere (`index(msg,':2:')`),
so padded fragments are a latent test-brittleness hazard.
**Fix:** Make `int2str` return `character(len=:), allocatable` (`res = trim(adjustl(buf))`),
or `trim()` the call site: `... // trim(int2str(nf))`.

---

_Reviewed: 2026-06-29T08:43:16Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
