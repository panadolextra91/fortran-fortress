# Phase 3: Day-Night Cycle & Scenario Comparison - Pattern Map

**Mapped:** 2026-06-29
**Files analyzed:** 9 (3 new src, 3 new test, 4 modified incl. coeffs.nml)
**Analogs found:** 9 / 9 (every new/modified file has a strong in-repo analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/diurnal.f90` (NEW) | utility / pure selector | transform (lookup) | `src/uhi.f90` (pure kernel module skeleton) + `src/grid.f90` (`coeffs_t`) | role-match |
| `src/scenario.f90` (NEW) | service / orchestration | transform (copy-then-mutate) | `src/uhi.f90` (elemental kernel) + `src/grid.f90` (`grid_t`/`cell`) | role-match |
| `src/summary.f90` (NEW) | service / reduction | batch (masked reduction) | `src/feels.f90` (pure-function-over-grid module) | role-match |
| `src/feels.f90` (MODIFY) | model / kernel | transform | itself (Phase 2) — add one scalar arg | exact (self) |
| `src/grid.f90` (MODIFY) | model / derived types | n/a | itself — extend `coeffs_t` | exact (self) |
| `src/io.f90` (MODIFY) | config loader | file-I/O | `read_coeffs_nml` in itself | exact (self) |
| `data/coeffs.nml` (MODIFY) | config | file-I/O | itself | exact (self) |
| `app/main.f90` (MODIFY) | driver / composition root | request-response | itself (single-pass loop → nested loop) | exact (self) |
| `test/test_diurnal.f90` (NEW) | test | n/a | `test/test_ordering.f90` | exact |
| `test/test_scenario.f90` (NEW) | test | n/a | `test/test_ordering.f90` | exact |
| `test/test_gap.f90` (NEW) | test | n/a | `test/test_ordering.f90` | exact |

---

## Shared Patterns (apply to ALL new src files)

### S1 — Module skeleton: `private` + explicit `public` + `use ..., only:`
**Source:** `src/uhi.f90:1-7`, `src/feels.f90:1-9`
Every module: `use kinds_mod, only: wp`, `implicit none`, `private`, then explicit `public ::` list. One module per file.
```fortran
module uhi_mod
    use kinds_mod, only: wp
    implicit none
    private
    public :: uhi_offset
contains
    ! ...
end module uhi_mod
```
**Apply to:** `diurnal_mod`, `scenario_mod`, `summary_mod`.

### S2 — Elemental pure kernel signature (scalar/array broadcast)
**Source:** `src/uhi.f90:9-20`, `src/feels.f90:12-23`
`elemental pure function` with all `intent(in)`, single scalar `result`. `merge(1.0_wp, 0.0_wp, logical)` to numify a logical; `_wp` on every literal; no integer division.
```fortran
elemental pure function uhi_offset(building, tree, water_km, is_urban, &
                                   w_build, w_urban, w_tree, w_water, d0) result(dT)
    real(wp), intent(in) :: building, tree, water_km
    logical,  intent(in) :: is_urban
    real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
    real(wp) :: dT, U, Wprox
    U     = merge(1.0_wp, 0.0_wp, is_urban)
    Wprox = exp(-water_km/d0)
    dT = w_build*building + w_urban*U - w_tree*tree - w_water*Wprox
end function uhi_offset
```
**Apply to:** the threaded `feels_like_c`, scenario clamp expression, gap reduction (kept `pure`, not `elemental` for the array-arg reduction).

### S3 — Float conversions / clamp via intrinsics, not `if` ladders
**Source:** `src/constants.f90:27-37` (`c_to_f`/`f_to_c`), RESEARCH §3.
Clamp a driver to [0,1] with `min(1.0_wp, max(0.0_wp, x))` broadcast elementally over `work%cells%tree`. No integer division — wrap counts with `real(count(mask), wp)`.

---

## Pattern Assignments

### `src/diurnal.f90` — `diurnal_mod` (utility, transform/lookup)

**Analog:** `src/uhi.f90` (module skeleton) + `src/grid.f90:23-28` (`coeffs_t` source of `m_*`).

**Module skeleton + named-constant lookup** — model on `uhi_mod` skeleton, add `select case` over the existing dormant `coeffs%m_*` fields. RESEARCH §2 gives the exact target:
```fortran
module diurnal_mod
    use kinds_mod, only: wp
    use grid_mod,  only: coeffs_t
    implicit none
    private
    public :: NT, T_MORNING, T_AFTERNOON, T_EVENING, T_PREDAWN, &
              diurnal_m, diurnal_base, time_label
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
    ! diurnal_base mirrors over c%base_morning/afternoon/evening/predawn
end module diurnal_mod
```
**Note:** `m_*` already exist in `coeffs_t` (`src/grid.f90:25`); `base_*` are added by the grid.f90 modification below.

---

### `src/scenario.f90` — `scenario_mod` (service, copy-then-mutate)

**Analog:** `src/grid.f90` (`grid_t`/`cell` types) + `src/uhi.f90` (elemental clamp style).

**`type(scenario_t)` + one-driver clamped mutation** (RESEARCH §3, CONTEXT D-06/D-07). Exactly one delta non-zero per scenario; clamp via intrinsics broadcast over `work%cells`:
```fortran
type, public :: scenario_t
    character(len=:), allocatable :: label
    real(wp) :: tree_delta     = 0.0_wp   ! exactly one non-zero (D-06)
    real(wp) :: building_delta = 0.0_wp
end type scenario_t

subroutine apply_scenario(work, scen)        ! work is ALREADY a deep copy of baseline
    type(grid_t),     intent(inout) :: work
    type(scenario_t), intent(in)    :: scen
    work%cells%tree     = min(1.0_wp, max(0.0_wp, work%cells%tree     + scen%tree_delta))
    work%cells%building = min(1.0_wp, max(0.0_wp, work%cells%building + scen%building_delta))
end subroutine apply_scenario
```
**Copy-then-mutate primitive** (intrinsic assignment deep-copies allocatable `cells(:,:)` and each `name`): `work = baseline` then `call apply_scenario(work, scen)`. Baseline never mutated (SCEN-01).
**Guards:** Do NOT `allocate(work%cells(...))` inside the loop (PITFALLS A8) — let assignment allocate. No declaration-init accumulators (A4).

---

### `src/summary.f90` — `summary_mod` (service, masked reduction)

**Analog:** `src/feels.f90` (pure-function module over grid data).

**Masked reduction with integer-division guard** (RESEARCH §4, CONTEXT D-09; PITFALLS A2):
```fortran
pure function urban_rural_gap(feels, g) result(gap)
    real(wp),     intent(in) :: feels(:,:)
    type(grid_t), intent(in) :: g
    real(wp) :: gap
    logical  :: mu(size(feels,1), size(feels,2)), mr(size(feels,1), size(feels,2))
    mu = g%cells%is_urban        .and. g%cells%occupied
    mr = (.not. g%cells%is_urban) .and. g%cells%occupied
    gap = sum(feels, mask=mu) / real(count(mu), wp) &      ! real() guards int division (A2)
        - sum(feels, mask=mr) / real(count(mr), wp)
end function urban_rural_gap
! city_average(feels, g) = sum(feels, mask=occupied)/real(count(occupied),wp)
```
Guard `count(mu) > 0` / `count(mr) > 0` before dividing. Compute `feels` for ALL cells before masking (so `-finit-real=snan` finds no uninitialised reads).

---

### `src/feels.f90` (MODIFY) — thread `m` into the kernel

**Analog:** itself, lines 12-23 (the ONLY change is one scalar arg).

Current (`src/feels.f90:12-23`):
```fortran
elemental pure function feels_like_c(t_base, rh, building, tree, water_km, is_urban, &
                                     w_build, w_urban, w_tree, w_water, d0) result(feels_c)
    ...
    t_adj_c = t_base + uhi_offset(building, tree, water_km, is_urban, &
                                  w_build, w_urban, w_tree, w_water, d0)
```
Target (insert `m` as 2nd positional arg; scale the offset — RESEARCH §1, A5):
```fortran
elemental pure function feels_like_c(t_base, m, rh, building, tree, water_km, is_urban, &
                                     w_build, w_urban, w_tree, w_water, d0) result(feels_c)
    real(wp), intent(in) :: t_base, m, rh, building, tree, water_km
    ...
    t_adj_c = t_base + m * uhi_offset(building, tree, water_km, is_urban, &
                                      w_build, w_urban, w_tree, w_water, d0)
```
**Blast radius (CLAUDE.md mandates impact analysis — 2 call sites):**
- `app/main.f90:39` — replaced by the timestep loop (passes `base_t, m_t` per `it`).
- `test/test_ordering.f90` — ~15 calls (lines 40-53, 81-101, 118). Insert `1.0_wp` as 2nd arg; `m=1` reproduces Phase-2 behaviour and keeps all Phase-2 assertions valid.

---

### `src/grid.f90` (MODIFY) — extend `coeffs_t`

**Analog:** itself, lines 23-28.

`coeffs_t` already has `m_morning, m_afternoon, m_evening, m_predawn` (line 25). Add parallel `base_*` + scenario deltas:
```fortran
type, public :: coeffs_t
    real(wp) :: w_build, w_urban, w_tree, w_water
    real(wp) :: m_morning, m_afternoon, m_evening, m_predawn
    real(wp) :: base_morning, base_afternoon, base_evening, base_predawn   ! NEW
    real(wp) :: add_trees_delta, concrete_delta                            ! NEW
    real(wp) :: t_base, rh_base, d0
    integer :: nx, ny
end type coeffs_t
```
`grid_t`/`cell` (lines 6-21) are unchanged; scenarios mutate `building`/`tree` only.

---

### `src/io.f90` (MODIFY) — namelist read with load-time validation

**Analog:** itself, `read_coeffs_nml` lines 13-80.

Existing pattern to copy verbatim — local var → defaults-first → `namelist` group → read → validate → assign to `c%`:
1. Declare 6 new locals next to `m_morning...` (line 20-21).
2. Add to `namelist /coeffs/` list (lines 25-27).
3. Set defaults FIRST (after line 37, before `open`): `base_morning=29.0_wp`, `base_afternoon=33.0_wp`, `base_evening=30.0_wp`, `base_predawn=25.0_wp`, `add_trees_delta=0.2_wp`, `concrete_delta=0.2_wp` (RESEARCH §5, A1/A2).
4. Add validation after the `d0 <= 0` check (lines 61-65), following its exact fail-loud `stat`/`msg` shape:
```fortran
if (d0 <= 0.0_wp) then
    stat = 1
    msg = trim(path) // ': d0 must be > 0'
    return
end if
! NEW — each base_* within [T_MIN, T_MAX]; each delta in (0,1]
if (base_predawn < T_MIN .or. base_afternoon > T_MAX) then
    stat = 1; msg = trim(path) // ': base_* out of range [10,50]'; return
end if
if (add_trees_delta <= 0.0_wp .or. add_trees_delta > 1.0_wp) then
    stat = 1; msg = trim(path) // ': add_trees_delta must be in (0,1]'; return
end if
```
   (`T_MIN`/`T_MAX` already imported at `src/io.f90:3`.)
5. Assign to `c%base_* = base_*` etc. after line 79.

---

### `data/coeffs.nml` (MODIFY)

**Analog:** itself (lines 1-15). Insert before the closing `/`:
```fortran
  base_morning   = 29.0
  base_afternoon = 33.0
  base_evening   = 30.0
  base_predawn   = 25.0
  add_trees_delta = 0.2
  concrete_delta  = 0.2
```

---

### `app/main.f90` (MODIFY) — nested timestep × scenario loop

**Analog:** itself, lines 36-53 (single-pass occupied-cell loop → nested loop).

- `use diurnal_mod, only: NT, diurnal_m, diurnal_base, time_label`; `use scenario_mod, only: scenario_t, apply_scenario`; `use summary_mod, only: urban_rural_gap, city_average`.
- Build 3 `scenario_t` in code (baseline, add_trees, more_concrete) from `coeffs%add_trees_delta`/`concrete_delta` (D-05).
- Allocate `work` grid ONCE (or rely on same-shape intrinsic assignment); loop `s` over scenarios → `work = baseline` (deep copy) → `apply_scenario` → loop `it=1..NT`: `m_t=diurnal_m(coeffs,it)`, `base_t=diurnal_base(coeffs,it)`, fill `feels(:,:)` via elemental `feels_like_c(base_t, m_t, work%cells%rh, ...)`, `gap(it)=urban_rural_gap(feels,work)`.
- Minimal console (D-12) — reuse the existing `write(output_unit, ...)` + `g0`/`F0.2` width-free style (lines 42-50, pre-empts A9 `*****`): one gap line per timestep, one city-avg-delta line per scenario.
- Keep accumulators initialised in the executable body, never declaration-init (A4).

---

### `test/test_diurnal.f90`, `test/test_scenario.f90`, `test/test_gap.f90` (NEW)

**Analog:** `test/test_ordering.f90` (entire file) — exact harness match.

**Program skeleton + collect** (`test/test_ordering.f90:1-24`):
```fortran
program test_gap
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use feels_mod, only: feels_like_c
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)
    testsuites = [ new_testsuite('gap', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1
contains
    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(N))
        testsuite(1) = new_unittest('name', test_proc)
    end subroutine collect
    ! ... subroutine test_proc(error) with check(error, ...) ...
end program test_gap
```

**In-test synthetic archetypes** (`test/test_ordering.f90:26-65`) — declare local `w_*`/`d0`/`rh`, set with `_wp` literals in the executable body, call `feels_like_c` directly (NOW with the `m` 2nd arg). `check(error, cond)` then `if (allocated(error)) return` between assertions.

- **test_diurnal:** selector values + `m=1` regression (Phase-2 archetypes equal at `m=1.0_wp`).
- **test_scenario:** immutability (baseline unchanged after copy-mutate), one-driver, clamp at [0,1], delta sign (add_trees lowers, more_concrete raises city-avg).
- **test_gap:** HARD `check(error, gap_predawn > gap_afternoon)`; night-sanity (pre-dawn rural feels in [21,26] °C); SOFT magnitude `write(error_unit,'(A,F0.2,A)')` warn-not-fail (RESEARCH §6, D-10). Use urban-core vs rural archetype sets from RESEARCH §6.

**Registration:** add the three programs as `[[test]]` targets in `fpm.toml` (mirror existing test entries).

---

## No Analog Found

None. Every new file maps to an existing in-repo analog (pure-kernel modules, the `read_coeffs_nml` namelist pattern, and the `test_ordering.f90` test-drive harness cover all three new modules and three new tests).

## Metadata

**Analog search scope:** `src/`, `app/`, `test/`, `data/` (entire codebase — 11 source/test files).
**Files scanned:** `feels.f90`, `uhi.f90`, `grid.f90`, `io.f90`, `constants.f90`, `main.f90`, `coeffs.nml`, `test_ordering.f90` (read in full).
**Pattern extraction date:** 2026-06-29
