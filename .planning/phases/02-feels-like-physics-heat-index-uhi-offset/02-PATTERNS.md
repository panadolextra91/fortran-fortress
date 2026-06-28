# Phase 2: Feels-Like Physics (Heat Index + UHI Offset) - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 9 (4 new src, 1 new src optional wrapper already counted, 3 modified, 3 new tests)
**Analogs found:** 9 / 9 (every target has an in-repo analog — this is a mature Phase-1 scaffold)

All analogs are concrete excerpts from the existing codebase read this session. Planner should
require `_wp` on every numeric literal (PITFALLS A1) in all new physics code.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/heat_index.f90` (NEW `heat_index_mod`) | utility/physics-kernel | transform | `src/constants.f90` (module skeleton) + `src/grid.f90` (private/public layout) | role-match |
| `src/uhi.f90` (NEW `uhi_mod`) | utility/physics-kernel | transform | same as above | role-match |
| `src/feels.f90` (NEW `feels_mod` wrapper) | utility/physics-composer | transform | `heat_index_mod`/`uhi_mod` (sibling kernels) + module skeleton | role-match |
| `src/constants.f90` (MODIFY: add `c_to_f`/`f_to_c` + Rothfusz coeffs) | config/foundation | transform | `src/constants.f90` itself (existing parameter block) | exact |
| `src/grid.f90` (MODIFY: add `d0` to `coeffs_t`) | model | — | `src/grid.f90` `coeffs_t` definition (lines 23-28) | exact |
| `src/io.f90` (MODIFY: `read_coeffs_nml` add `d0`) | service/IO | request-response (file read) | `src/io.f90` `read_coeffs_nml` (lines 13-72) | exact |
| `data/coeffs.nml` (MODIFY: add `d0 = 2.5`) | config | — | `data/coeffs.nml` existing entries | exact |
| `app/main.f90` (MODIFY: wire feels-like into cell loop) | driver | request-response | `app/main.f90` District List loop (lines 34-47) | exact |
| `test/test_heat_index.f90` (NEW) | test | transform | `test/test_io.f90` (full test-drive harness) | role-match |
| `test/test_uhi.f90` (NEW) | test | transform | `test/test_io.f90` | role-match |
| `test/test_ordering.f90` (NEW) | test | transform | `test/test_io.f90` | role-match |

## Pattern Assignments

### `src/heat_index.f90` — NEW `heat_index_mod` (physics kernel, transform)

**Analog (module skeleton):** `src/constants.f90` lines 1-5 + `src/grid.f90` lines 1-5, 30-32, 44-45

**Module header + private/public pattern** (mirror `constants_mod` / `grid_mod`):
```fortran
module heat_index_mod
    use kinds_mod, only: wp
    implicit none
    private
    public :: heat_index_f
contains
    ! ... elemental pure function here ...
end module heat_index_mod
```
- Every existing module is `private` with explicit `public` exports and `use kinds_mod, only: wp`
  (VERIFIED: `src/constants.f90:1-4`, `src/grid.f90:1-4`, `src/io.f90:1-6`). Keep one `public`
  line listing only `heat_index_f`.
- If the Rothfusz coefficients live in `constants_mod` (recommended, PITFALLS A1), add
  `use constants_mod, only: <coeff names>` following the `use ..., only:` discipline seen in
  `io_mod` (`src/io.f90:2-4`).

**Kernel signature** (from RESEARCH §Code Examples; no derived type — plain scalars):
```fortran
elemental pure function heat_index_f(t_f, rh) result(hi)
    real(wp), intent(in) :: t_f, rh
    real(wp) :: hi
    ...
end function heat_index_f
```
- The repo has no existing `elemental pure` function (Phase-1 is all subroutines), so the
  *signature style* comes from RESEARCH, but the **declaration idiom** (`real(wp), intent(in) ::`,
  result variable typed `real(wp)`) matches every Phase-1 procedure local-declaration block
  (e.g. `src/io.f90:19-22, 86-87`).

**No I/O, no `error stop`, no validation in the kernel** — Phase-1 keeps validation in the loader
(`src/io.f90:147-156`); kernels assume already-validated inputs (CONTEXT "physics kernels stay
pure"). This is an elemental-procedure hard requirement.

---

### `src/uhi.f90` — NEW `uhi_mod` (physics kernel, transform)

**Analog:** same module skeleton as `heat_index_mod` above.

**Kernel signature + `merge` for the urban flag** (RESEARCH §UHI offset):
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
- `is_urban` is `logical` on `type(cell)` (VERIFIED: `src/grid.f90:14`). Use `merge(1.0_wp,
  0.0_wp, is_urban)` — never multiply a logical (PITFALLS A2).
- All budget drivers are `real(wp)` on `cell` (VERIFIED: `src/grid.f90:11-13`); `water_km/d0` is
  real/real division — fine. `d0` must be `real(wp)` and `> 0` (see security note below).

---

### `src/feels.f90` — NEW `feels_mod` thin wrapper (composer, transform)

**Analog:** the two sibling kernels + module skeleton.

```fortran
module feels_mod
    use kinds_mod, only: wp
    use heat_index_mod, only: heat_index_f
    use uhi_mod, only: uhi_offset
    use constants_mod, only: c_to_f, f_to_c
    implicit none
    private
    public :: feels_like_c
contains
    elemental pure function feels_like_c(t_base, rh, building, tree, water_km, is_urban, &
                                         w_build, w_urban, w_tree, w_water, d0) result(feels_c)
        real(wp), intent(in) :: t_base, rh, building, tree, water_km
        logical,  intent(in) :: is_urban
        real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
        real(wp) :: feels_c, t_adj_c, hi_f
        t_adj_c = t_base + uhi_offset(building, tree, water_km, is_urban, &
                                      w_build, w_urban, w_tree, w_water, d0)
        hi_f    = heat_index_f(c_to_f(t_adj_c), rh)
        feels_c = max(f_to_c(hi_f), t_adj_c)     ! floor D-09
    end function feels_like_c
end function ! (planner: end function/end module)
```
- Floor reference is `t_adj_c`, not `cell%t_air` (RESEARCH Assumption A2 — flag for confirmation,
  but consistent with D-01 using `t_base`).
- The `use ..., only:` import-of-siblings mirrors `io_mod` importing `grid_mod`/`constants_mod`
  (VERIFIED: `src/io.f90:2-4`).

---

### `src/constants.f90` — MODIFY (add °C↔°F helpers + Rothfusz coefficients)

**Analog:** the file itself — extend the existing parameter block (lines 6-11) and add a
`contains` section (constants_mod currently has none).

**Existing parameter style to mirror** (`src/constants.f90:6-11`):
```fortran
real(wp), parameter, public :: T_MIN = 10.0_wp
real(wp), parameter, public :: T_MAX = 50.0_wp
```
- Add named Rothfusz coefficients the same way: `real(wp), parameter, public :: HI_C1 = -42.379_wp`
  etc. (PITFALLS A1 — named parameters guarantee the kind and aid readability).

**Add a `contains` block with the two elemental helpers** (RESEARCH §°C↔°F):
```fortran
elemental pure function c_to_f(c) result(f)
    real(wp), intent(in) :: c
    real(wp) :: f
    f = c*9.0_wp/5.0_wp + 32.0_wp
end function c_to_f

elemental pure function f_to_c(f) result(c)
    real(wp), intent(in) :: f
    real(wp) :: c
    c = (f - 32.0_wp)*5.0_wp/9.0_wp
end function f_to_c
```
- Note: `constants_mod` currently ends at `end module` with no `contains`; planner must add
  `public :: c_to_f, f_to_c`, a `contains` line, then the functions, before `end module`.

---

### `src/grid.f90` — MODIFY `coeffs_t` (add `d0`)

**Analog:** the `coeffs_t` definition itself (`src/grid.f90:23-28`):
```fortran
type, public :: coeffs_t
    real(wp) :: w_build, w_urban, w_tree, w_water
    real(wp) :: m_morning, m_afternoon, m_evening, m_predawn
    real(wp) :: t_base, rh_base
    integer :: nx, ny
end type coeffs_t
```
- Add `real(wp) :: d0` (one new component, e.g. after `t_base, rh_base`). Pure schema addition,
  no migration (RESEARCH Runtime State Inventory).
- **GitNexus note (CLAUDE.md):** run `impact({target: "coeffs_t", direction: "upstream"})` before
  editing — `coeffs_t` is consumed by `io_mod` and `app/main.f90`.

---

### `src/io.f90` — MODIFY `read_coeffs_nml` (the exact namelist template)

**Analog:** `read_coeffs_nml` itself (`src/io.f90:13-72`) — this is the precise three-edit pattern.

**1. Declare local** (mirror `src/io.f90:19-22`):
```fortran
real(wp) :: d0    ! add alongside the other real locals
```
**2. Add to the namelist group** (`src/io.f90:25-27`):
```fortran
namelist /coeffs/ w_build, w_urban, w_tree, w_water, &
                  m_morning, m_afternoon, m_evening, m_predawn, &
                  t_base, rh_base, d0, nx, ny
```
**3a. Set default BEFORE open/read** (mirror `src/io.f90:30-41`):
```fortran
d0 = 2.5_wp
```
**3b. Copy into coeffs_t after read** (mirror `src/io.f90:60-71`):
```fortran
c%d0 = d0
```
- **Validation (security V5 / D-05 fail-loud convention):** add a `d0 > 0` guard after the read
  to prevent divide-by-zero in `exp(-water_km/d0)`, mirroring the fail-loud bounds checks in
  `read_grid_csv` (`src/io.f90:151-156`) — set `stat`, write `msg`, `return`. Existing
  `read_coeffs_nml` has no post-read validation, so this is a new (small) addition following the
  CSV-loader pattern.
- Defaults are set before `read`, so existing fixtures omitting `d0` (`test/fixtures/coeffs.nml`,
  `coeffs_partial.nml`) still load (matches `test_coeffs_partial`, `test/test_io.f90:107-119`).
- **GitNexus note:** run `impact({target: "read_coeffs_nml", direction: "upstream"})` first.

---

### `data/coeffs.nml` — MODIFY (add `d0`)

**Analog:** `data/coeffs.nml` existing entries (lines 1-14). Add `d0 = 2.5` (e.g. after
`rh_base = 78.0`, before `nx`). Note: data file uses bare literals (no `_wp`) — that is correct
for namelist input; `_wp` discipline applies to source code only.

---

### `app/main.f90` — MODIFY (wire feels-like into the District List loop)

**Analog:** the existing occupied-cell print loop (`app/main.f90:34-47`).

**Add import** (mirror the `use` block at `app/main.f90:1-5`):
```fortran
use feels_mod, only: feels_like_c
```
**Declare a local** (mirror `app/main.f90:15-16`):
```fortran
real(wp) :: feels
```
**Inside the `if (occupied)` block, before the write** (the loop is `app/main.f90:36-44`):
```fortran
feels = feels_like_c(coeffs%t_base, grid%cells(i,j)%rh, grid%cells(i,j)%building, &
                     grid%cells(i,j)%tree, grid%cells(i,j)%water_km, grid%cells(i,j)%is_urban, &
                     coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
```
**Extend the existing write** (`app/main.f90:37-44`) — append `', FEELS=', feels` to the format
and argument list (the format already uses chained `g0` edit descriptors for each value).
- Do NOT add a `feels_like` component to `type(cell)` (Anti-Pattern; breaks Phase-3 multi-timestep).
- Do NOT consume any `m_*` field (D-06 / PITFALLS Pitfall 4).
- **GitNexus note:** `app/main.f90` is the program driver — run `detect_changes()` before commit.

---

### `test/test_heat_index.f90`, `test/test_uhi.f90`, `test/test_ordering.f90` — NEW (test-drive)

**Analog:** `test/test_io.f90` (full harness, lines 1-32) — copy its structure exactly.

**Program header + single-suite registration** (`test/test_io.f90:1-18`):
```fortran
program test_heat_index
    use testdrive, only: new_unittest, unittest_type, testsuite_type, &
                         new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use heat_index_mod, only: heat_index_f
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)
    testsuites = [ new_testsuite('heat_index', collect) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1
contains
```
- The repo registers a single suite and runs `testsuites(1)` only (VERIFIED: `test/test_io.f90:
  12-18`) — follow the same single-suite-per-program form.

**Collect subroutine** (mirror `test/test_io.f90:22-32`):
```fortran
subroutine collect(testsuite)
    type(unittest_type), allocatable, intent(out) :: testsuite(:)
    allocate(testsuite(N))
    testsuite(1) = new_unittest('ref_values', test_ref)
    ! ...
end subroutine collect
```

**Per-test subroutine + check idiom** (mirror `test/test_io.f90:34-49`, `93-105`):
```fortran
subroutine test_ref(error)
    type(error_type), allocatable, intent(out) :: error
    call check(error, abs(heat_index_f(90.0_wp, 70.0_wp) - 105.9220_wp) < 1.0e-2_wp)
    if (allocated(error)) return
    call check(error, abs(heat_index_f(86.0_wp, 90.0_wp) - 105.3944_wp) < 1.0e-2_wp)
end subroutine test_ref
```
- The `abs(...) < tol` float-comparison idiom is exactly how Phase-1 tests assert reals
  (VERIFIED: `test/test_io.f90:47, 104, 118`).
- `if (allocated(error)) return` guard between checks matches `test/test_io.f90:43, 45, 101, 115`.
- **Assert targets (heat index):** use the RESEARCH §NWS Reference Values table — `90/70→105.9220`,
  `86/90→105.3944`, `79/70→79.4450` (Steadman), `75/80→75.4800` (cool/floor). Tol `1.0e-2_wp`.
- **`test_uhi.f90`:** monotonicity/sign checks (D-11) via rank/sign, e.g.
  `check(error, uhi_offset(0.8_wp,...) > uhi_offset(0.2_wp,...))` for ↑building, etc.
- **`test_ordering.f90`:** build synthetic archetype scalars in-test (D-10), call `feels_like_c`,
  assert `feels_industrial > feels_park`, `... > feels_cangio`, `... > feels_rural`.
- **Auto-discovery:** `fpm.toml` has `auto-tests = true` (VERIFIED: `fpm.toml:6`) — new
  `test/test_*.f90` programs are picked up with no manifest edit.

## Shared Patterns

### Module skeleton (applies to all 3 new src modules)
**Source:** `src/constants.f90:1-12`, `src/grid.f90:1-5,30-45`, `src/io.f90:1-11`
```fortran
module <name>_mod
    use kinds_mod, only: wp
    implicit none
    private
    public :: <only the exported names>
contains
    ! procedures
end module <name>_mod
```
**Apply to:** `heat_index.f90`, `uhi.f90`, `feels.f90`, and the extended `constants.f90`.

### `_wp` literal discipline (applies to ALL new physics source)
**Source:** `src/constants.f90:6-11`, `src/io.f90:30-39` (every literal already suffixed)
**Apply to:** every numeric literal in the kernels and constants — including conversion constants
(`9.0_wp/5.0_wp`, `32.0_wp`) and the nine Rothfusz coefficients (PITFALLS A1; Rothfusz cancellation
is visible at single precision). Does NOT apply to `data/coeffs.nml` (namelist input file).

### Elemental-kernel constraint (applies to all 3 new src modules)
**Source:** RESEARCH Anti-Patterns + ARCHITECTURE anti-pattern 1
No `print`/`write`/`error stop`/validation inside `elemental pure` functions. Validation stays in
the loader, mirroring the fail-loud bounds checks in `read_grid_csv` (`src/io.f90:147-163`).

### test-drive harness (applies to all 3 new tests)
**Source:** `test/test_io.f90:1-32`
Single `new_testsuite` registered, run `testsuites(1)%collect`, `error stop 1` on failure;
`allocate(testsuite(N))` + `new_unittest('name', proc)`; `call check(error, <logical>)` with
`if (allocated(error)) return` between assertions; reals via `abs(a-b) < tol`.

### Build/test flags (LOCKED — surface to planner; MEMORY fact)
**Source:** RESEARCH §Build/test flag note + project MEMORY (`fpm-rejects-manifest-profiles`)
fpm 0.13.0 rejects `[profiles.*.gfortran]`. Pass strict dev flags on the CLI, never in `fpm.toml`:
```bash
fpm test --flag "-std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan"
fpm run  --flag "-std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -finit-real=snan"
```

## No Analog Found

None. Every Phase-2 target maps to an existing Phase-1 file — modified files are edits in place,
and new physics/test files reuse the established module skeleton and test-drive harness. The only
*novel idiom* (an `elemental pure function`) has no Phase-1 instance, but its declaration style
(`real(wp), intent(in)`, typed result var) is identical to existing procedure local-declaration
blocks, so the planner has a concrete in-repo template for everything except the `elemental pure`
prefix keyword itself (which comes from RESEARCH §Code Examples).

## Metadata

**Analog search scope:** `src/`, `app/`, `test/`, `data/`, `fpm.toml`
**Files scanned:** 9 source/data/test/config files (all read in full this session)
**Pattern extraction date:** 2026-06-28
