# Phase 4: CSV Export & Console Summary - Pattern Map

**Mapped:** 2026-06-29
**Files analyzed:** 4 (1 modify or new, 1 modify, 1 modify, 1 new test)
**Analogs found:** 4 / 4 (all exact or strong, in-repo)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/io.f90` (add `write_results_csv`) **or** new `src/output.f90` | io / writer module | file-I/O (write) | `src/io.f90` `read_grid_csv` (open/`newunit`/formatted loop/close) | exact (inverse direction) |
| `src/summary.f90` (add `hottest`/`coolest`) | reductions module | transform / reduce-over-mask | `src/summary.f90` `urban_rural_gap` / `city_average` | exact (same file, same idiom) |
| `app/main.f90` (retain feels, write CSV, print OUT-02 table) | driver / program | batch + request-response (console) | `app/main.f90` itself (existing scenario→timestep→(i,j) loop + console print) | exact (in-place rewire) |
| `test/test_output.f90` (new) | test | request-response (assert) | `test/test_io.f90` (test-drive harness) | exact (same framework) |

## Conventions to replicate (all files)

- Kind: `use kinds_mod, only: wp` — every real literal carries `_wp` (e.g. `0.0_wp`). PITFALLS A-style: never bare literals.
- Module shape: `module x_mod` / `implicit none` / `private` / explicit `public :: ...` / `contains`. One module per file.
- Imports: `use module, only: name` exclusively (see every `src/*.f90` header).
- Kernels stay `elemental pure` / reductions `pure` — do NOT touch `feels_mod`/`uhi_mod`/`diurnal_mod`/`scenario_mod`.
- Fail-loud at load time only; output code uses formatted `write`, no global state.
- No integer division — wrap counts with `real(count(...), wp)` (see summary excerpt below).

---

## Pattern Assignments

### `src/io.f90` `write_results_csv` (or `src/output.f90`) — writer, file-I/O

**Analog:** `src/io.f90` (the open/`newunit`/close mechanics of `read_grid_csv`, run in reverse for writing).

**Module header + public + kinds** (`src/io.f90` lines 1-11) — replicate exactly, add the new public:
```fortran
module io_mod
    use kinds_mod, only: wp
    use constants_mod, only: T_MIN, T_MAX, RH_MIN, RH_MAX, DEN_MIN, DEN_MAX
    use grid_mod, only: cell, grid_t, coeffs_t, allocate_grid
    implicit none
    private
    public :: read_coeffs_nml, read_grid_csv   ! add: write_results_csv
```
If a new `src/output_mod` is chosen instead, it needs `use grid_mod, only: grid_t, coeffs_t` plus `use diurnal_mod, only: NT, diurnal_base, diurnal_m, time_label` and `use uhi_mod, only: uhi_offset` to compute the row columns (see Integration below).

**`newunit` open pattern** (`src/io.f90` lines 143-147) — mirror for writing (`status='replace', action='write'` per D-05 overwrite):
```fortran
open(newunit=u, file=path, status='old', action='read', iostat=ios, iomsg=msg)
if (ios /= 0) then
    stat = ios
    return
end if
```
For the writer: `open(newunit=u, file='results.csv', status='replace', action='write', iostat=ios, iomsg=msg)`.

**Subroutine signature convention** (`src/io.f90` lines 124-129) — `stat`/`msg` out-args, `intent` on everything:
```fortran
subroutine read_grid_csv(path, nx, ny, g, stat, msg)
    character(len=*), intent(in) :: path
    integer, intent(in) :: nx, ny
    type(grid_t), intent(out) :: g
    integer, intent(out) :: stat
    character(len=*), intent(out) :: msg
    integer :: u, ios
```

**Header + close** (`src/io.f90` lines 150, 231) — read pattern; writer emits the header line first then closes:
```fortran
read(u, '(A)', iostat=ios) line   ! reader skips header
...
close(u)
```
Writer: `write(u, '(A)') 'i,j,name,time_label,scenario,t_air,base_t,feels_c,uhi_offset_c'` then the row loop, then `close(u)`.

**Row write — D-04 columns, D-02 determinism, A9/A10 guards.** No analog write row in repo; construct from the formatted-write idiom seen in `make_msg` (`src/io.f90` lines 243, 251) which uses `write(buf, '(I0)')`. For data rows use explicit widths (guard A9 `*****`) and `F` edit descriptors which always emit `.` decimals (guard A10). Recommended row, comma-joined, no spaces:
```fortran
! per occupied cell, iteration order scenario -> it -> i -> j (D-02)
write(u, '(I0,",",I0,",",A,",",A,",",A,",",F0.2,",",F0.2,",",F0.2,",",F0.2)') &
    i, j, trim(name), trim(time_label(it)), trim(scen_label), &
    t_air, base_t, feels_c, uhi_offset_c
```
`F0.2` self-sizes (no `*****` overflow) and forces `.` — satisfies A9 and A10 together. Skip cells where `.not. occupied` (D-01: 168 data rows + 1 header).

---

### `src/summary.f90` `hottest` / `coolest` — reductions, transform over occupied mask

**Analog:** `src/summary.f90` `urban_rural_gap` / `city_average` (same file — copy the mask + `count`/`real(...,wp)` idiom; swap `sum` for `maxloc`/`minloc`).

**Module header** (`src/summary.f90` lines 1-6) — add the two publics:
```fortran
module summary_mod
    use kinds_mod, only: wp
    use grid_mod, only: grid_t
    implicit none
    private
    public :: urban_rural_gap, city_average   ! add: hottest, coolest
```

**Occupied-mask reduction idiom** (`src/summary.f90` lines 31-41, `city_average`) — replicate the guard + `real(count, wp)` shape:
```fortran
pure function city_average(feels, g) result(avg)
    real(wp), intent(in) :: feels(:,:)
    type(grid_t), intent(in) :: g
    real(wp) :: avg
    if (count(g%cells%occupied) > 0) then
        avg = sum(feels, mask=g%cells%occupied) / real(count(g%cells%occupied), wp)
    else
        avg = 0.0_wp
    end if
end function city_average
```

**Mask construction** (`src/summary.f90` lines 14-20, `urban_rural_gap`) — for `hottest`/`coolest`, build the occupied mask the same way:
```fortran
logical, allocatable :: mu(:,:)
allocate(mu(g%nx, g%ny))
mu = g%cells%occupied
```

**New `hottest` (and mirror `coolest` with `minloc`)** — `maxloc`/`minloc` over the masked field, returning cell index + value per D-07. `maxloc` with `mask=` honors only occupied cells; return the `(i,j)` so the driver can read `g%cells(i,j)%name`:
```fortran
pure subroutine hottest(feels, g, ih, jh, val)
    real(wp), intent(in) :: feels(:,:)
    type(grid_t), intent(in) :: g
    integer, intent(out) :: ih, jh
    real(wp), intent(out) :: val
    integer :: loc(2)
    loc = maxloc(feels, mask=g%cells%occupied)
    ih = loc(1); jh = loc(2)
    val = feels(ih, jh)
end subroutine hottest
```
(`coolest` = same body with `minloc`. Keep `pure`. The driver pulls the name via `g%cells(ih,jh)%name` — D-07 reports name + feels.)

---

### `app/main.f90` — driver rewire (retain feels, write CSV, OUT-02 console)

**Analog:** `app/main.f90` itself — the existing loop already computes `feels_current(i,j)` per scenario/timestep (lines 78-111). Phase 4 (a) retains feels across all scenario×timestep×cell, (b) calls the CSV writer, (c) replaces the minimal print (lines 102-109) with the OUT-02 table.

**Use block** (`app/main.f90` lines 1-10) — extend with the new writer + reductions:
```fortran
use io_mod, only: read_coeffs_nml, read_grid_csv          ! add: write_results_csv
use summary_mod, only: urban_rural_gap, city_average      ! add: hottest, coolest
use diurnal_mod, only: NT, diurnal_m, diurnal_base, time_label
use uhi_mod, only: uhi_offset                             ! add, for uhi_offset_c column
use, intrinsic :: iso_fortran_env, only: error_unit, output_unit
```

**Existing scenario→timestep→(i,j) loop to retain feels** (`app/main.f90` lines 78-96) — already the right shape; add a 4D retain array `feels_all(nx,ny,NT,3)` (D-09 collect-then-write) alongside the existing `feels_baseline`:
```fortran
do iscen = 1, 3
    work = baseline_grid
    call apply_scenario(work, scens(iscen))
    do it = 1, NT
        m_t = diurnal_m(coeffs, it)
        base_t = diurnal_base(coeffs, it)
        do j = 1, work%ny
            do i = 1, work%nx
                feels_val = feels_like_c(base_t, m_t, work%cells(i,j)%rh, ...)
                feels_current(i,j) = feels_val
                ! Phase 4: feels_all(i,j,it,iscen) = feels_val   <-- retain for CSV
            end do
        end do
    end do
end do
```

**`uhi_offset_c` column source** (D-04, Discretion) — recompute per row from the public kernel × diurnal factor (no kernel change):
```fortran
uhi_offset_c = m_t * uhi_offset(work%cells(i,j)%building, work%cells(i,j)%tree, &
               work%cells(i,j)%water_km, work%cells(i,j)%is_urban, &
               coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
```

**Console print to REPLACE** (`app/main.f90` lines 102-109) — the current minimal gap/dT lines become the OUT-02 baseline table + scenario-delta recap (D-06). Keep the aligned `write(output_unit, ...)` idiom; reuse `hottest`/`coolest`/`city_average`/`urban_rural_gap` per timestep, baseline scenario:
```fortran
! OLD (remove):
write(output_unit, '(A,A,F0.2,A)') trim(time_label(it)), ': gap = ', gap_t, ' C'
! NEW: per-timestep row -> hottest name+C, coolest name+C, city-avg, gap
```
Console reports feels-like only — do NOT print per-cell `t_air` next to feels (D-08). Keeping/removing the ASCII grid print (lines 43-58) is planner's call.

**CSV call** — after the loops, single call (D-09 collect-then-write):
```fortran
call write_results_csv('results.csv', baseline_grid, coeffs, feels_all, stat, msg)
if (stat /= 0) then
    write(error_unit, '(A)') trim(msg)
    error stop 1
end if
```
(Error-stop pattern copied verbatim from `app/main.f90` lines 29-32.)

---

### `test/test_output.f90` (new) — test, test-drive harness

**Analog:** `test/test_io.f90` (exact framework idiom). `fpm.toml` has `auto-tests = true` — a new `test/test_output.f90` is auto-discovered; no manifest edit needed.

**Harness scaffold** (`test/test_io.f90` lines 1-38) — copy verbatim, rename suite/collect:
```fortran
program test_output
    use testdrive, only: new_unittest, unittest_type, testsuite_type, new_testsuite, run_testsuite, error_type, check
    use kinds_mod, only: wp
    use io_mod, only: write_results_csv        ! or output_mod
    use, intrinsic :: iso_fortran_env, only: error_unit
    implicit none
    integer :: stat
    type(testsuite_type), allocatable :: testsuites(:)
    testsuites = [ new_testsuite('output_tests', collect_output_tests) ]
    stat = 0
    call run_testsuite(testsuites(1)%collect, error_unit, stat)
    if (stat > 0) error stop 1
contains
    subroutine collect_output_tests(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(N))
        testsuite(1) = new_unittest('csv_header', test_csv_header)
        ! ...
    end subroutine
```

**Single test body + `check`** (`test/test_io.f90` lines 40-55) — assert structure (header text, 168+1 row count, `.`-decimals present / no `,` decimal, no `*****` overflow), NOT exact °C (rank/sign-over-absolute, Phase 2 D-11 / Phase 3 D-10):
```fortran
subroutine test_csv_header(error)
    type(error_type), allocatable, intent(out) :: error
    ! write results to a temp/known path, reopen, read first line
    call check(error, header == 'i,j,name,time_label,scenario,t_air,base_t,feels_c,uhi_offset_c')
    if (allocated(error)) return
    call check(error, nrows == 169)            ! 168 data + 1 header (D-01)
    call check(error, index(some_row, '.') > 0) ! A10: '.' decimals
end subroutine
```

---

## Shared Patterns

### Kinds + literals
**Source:** every `src/*.f90` line 2 (`use kinds_mod, only: wp`).
**Apply to:** all new/modified files. Every real literal `_wp`.

### Formatted-write determinism (A9 / A10)
**Source:** `src/io.f90` `make_msg` lines 240-245 (`write(num_str, '(I0)')`).
**Apply to:** CSV writer rows. Use `I0` for ints, `F0.2` for reals — self-sizing (A9: no `*****`) and locale-independent `.` (A10). Comma literals in the format string, no surrounding spaces (D-02 byte-reproducible).
```fortran
write(num_str, '(I0)') lineno
```

### Reduction over occupied mask
**Source:** `src/summary.f90` lines 19-27, 36-37.
**Apply to:** `hottest`/`coolest`. `mask=g%cells%occupied`; guard empty with `count(...) > 0`; divide via `real(count(...), wp)` (no integer division).

### Error-stop on failure
**Source:** `app/main.f90` lines 28-32.
**Apply to:** driver CSV-write call.
```fortran
if (stat /= 0) then
    write(error_unit, '(A)') trim(msg)
    error stop 1
end if
```

### Module visibility
**Source:** `src/uhi.f90` lines 4-5, all modules.
**Apply to:** new/extended modules. `private` then explicit `public :: ...`.

## No Analog Found

None. Every Phase-4 file maps to an in-repo analog (writer = inverse of `read_grid_csv`; reductions = siblings in `summary_mod`; driver = in-place; test = `test_io.f90` clone).

## Metadata

**Analog search scope:** `src/`, `app/`, `test/`, `fpm.toml`
**Files scanned:** io.f90, summary.f90, main.f90, diurnal.f90, uhi.f90, grid.f90, test_io.f90, fpm.toml
**Pattern extraction date:** 2026-06-29
