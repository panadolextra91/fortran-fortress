# Phase 1: Build Scaffold & Grid Loader - Research

**Researched:** 2026-06-28
**Domain:** Modern Fortran (F2018) project scaffolding with fpm + delimited/namelist file loading and fail-loud validation
**Confidence:** HIGH (Fortran language idioms and the existing research corpus are HIGH; the *exact* fpm.toml custom-profile TOML syntax is MEDIUM and gated by an execute-time verification step because fpm is not yet installed)

## Summary

Phase 1 stands up an `fpm` project (replacing the throwaway Hello-World Makefile scaffold) and builds the foundation + data layers: `kinds_mod` (`wp = real64`), `constants_mod`, a `grid_mod` with `type(cell)` and an allocatable `grid_t`, and an `io_mod` that loads (a) a CSV district table and (b) a Fortran `namelist` of model coefficients. The driver loads, validates fail-loud (line number + reason), and prints the grid. No physics. Everything here is well-trodden modern-Fortran territory and the three research files (`STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md`) plus `FEATURES.md` already supply the stack, module decomposition, pitfalls, and HCMC seed values — this research operationalizes them into concrete, plannable patterns.

Two findings change the plan materially. **First**, fpm's *built-in* `release` profile for gfortran injects `-O3 -march=native -ffast-math -funroll-loops` — and `-ffast-math` + `-march=native` are explicitly forbidden by STACK.md/PITFALLS (they break IEEE semantics and are the wrong tuning knob on Apple-Silicon aarch64). The project therefore must **not** rely on `fpm build --profile release` as-is; it must define explicit flag sets and verify them. **Second**, the loader should follow ARCHITECTURE Pattern 5 (status-flag error handling): the *loader returns* `stat`/`msg`, and only the *driver* calls `error stop`. This keeps the malformed-row behavior unit-testable (a test can assert a bad row yields a nonzero stat) instead of un-catchably aborting the test process.

**Primary recommendation:** Hand-create `fpm.toml` (fpm not installed yet → `brew install fpm` first) using the default `app/`–`src/`–`test/` layout; put the driver in `app/main.f90` and all modules in `src/`; define the exact D-09 dev/release gfortran flag sets explicitly (do not inherit fpm's harmful default release flags) and confirm them at execute time with `fpm build --verbose`; implement the CSV reader as line-buffered → comma-split → per-field `iostat` parse → range-validate → return `stat`/`msg`; load coefficients via a `namelist` group with pre-seeded defaults.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Two-tier format. The **grid/district table is CSV** (one row per district, human-editable). The **model coefficients** (UHI weights `w_build`/`w_urban`/`w_tree`/`w_water`, diurnal multipliers, baseline weather) live in a **Fortran `namelist`** file (Fortran-native, no parser code, edit-without-recompile).
- **D-02:** Both files are plain-text, version-controlled, under a `data/` directory. Editing either changes program output with no recompile (satisfies GRID-01, GRID-04).
- **D-03:** The grid is a **list of districts, each carrying explicit `(i, j)` grid coordinates** on a 2D raster approximating the HCMC map. Real 2D heat map (cells have spatial position), each cell a named district. NOT a dense interpolated raster, NOT a coordinate-less 1D ranking.
- **D-04:** Empty grid cells (raster positions with no district) are expected and fine for Phase 1 — the loader holds the sparse district list with coordinates. Rendering of empty cells is deferred to Phase 4. Grid extent (max i, max j) is derived from the data **or** set in the namelist.
- **D-05:** Ship **~12–16 real HCMC districts** covering all five archetypes AND recognizable: District 1 (dense core), an industrial zone (parts of Thu Duc / Binh Tan — hottest), a park/green cell (Tao Dan area), Can Gio (mangrove/coast — coolest control), a peri-urban/rural fringe, plus familiar districts (3, 5, 7, 10, Binh Thanh, Tan Binh, Go Vap, ...).
- **D-06:** Per-cell fields (GRID-02): air temperature, relative humidity, distance to river/ocean, building density, tree density, urban/rural class — plus district name and `(i, j)`. All numeric fields stored/converted to `real(real64)` to avoid integer-division / precision loss downstream.
- **D-07:** **Fail loud, fail early.** A malformed or out-of-range row (bad column count, unparseable number, RH outside 0–100, density outside 0–1, etc.) stops the program with a clear message naming the **line number and the reason**. No silent skipping, no silent clamping. Validation runs at load time, before any physics.
- **D-08:** Build with **fpm**. Phase 1 creates `fpm.toml` and the `src/`/`test/`/`data/` layout, and **retires the Hello-World Makefile scaffold** (`Makefile`, `src/numerics.f90`, `src/main.f90`). `fpm build`/`fpm run`/`fpm test` must run clean. **fpm is not yet installed — install via `brew install fpm` at the start of execution.**
- **D-09:** Single real kind module (`kinds_mod`, `wp = real64`) and `implicit none` everywhere; strict dev flag profile (`-fcheck=all -Wall -Wextra -fimplicit-none -finit-real=snan`) vs a `-O2` release profile.

### Claude's Discretion
- Exact CSV column order/header names, the precise `(i,j)` coordinates assigned to each district, the namelist group/variable names, and the internal derived-type field names — left to research/planning, as long as the decisions above hold.

### Deferred Ideas (OUT OF SCOPE)
- **Rendering of empty grid cells** — belongs to Phase 4 (CSV Export & Console Summary).
- **Humidex toggle, continuous distance-to-water decay, smooth cosine diurnal curve, more districts/finer archetypes, seasonal runs** — v2 (`REFN-01..05`).
- **Tuning UHI weights so the night gap lands in ~3–8 °C** — a Phase 2/3 calibration concern; Phase 1 only needs the weights to *load*, not to be tuned.
- **All physics**: feels-like, heat index, UHI offset math, diurnal cycle, scenarios, CSV export — Phases 2–4.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GRID-01 | Loads a 2D grid of city cells from an editable data file (no recompile to change city data). | `io_mod` reads `data/hcmc_districts.csv` at runtime into an allocatable `grid_t`; grid extent from namelist (or derived). Editing the CSV changes output with no rebuild. See *Architecture Patterns* + *Code Examples* (CSV reader). |
| GRID-02 | Each cell carries air temp, relative humidity, distance to river/ocean, building density, tree density, urban/rural class. | `type(cell)` field design (see *Pattern: derived type + allocatable grid*); all numeric fields `real(wp)` (D-06) to avoid integer division (PITFALL A2). |
| GRID-03 | Seed file ships realistic HCMC district archetypes; malformed/out-of-range rows rejected loudly with line number. | ~12–16 seed rows from `FEATURES.md` HCMC Baselines (see *Seed Data*); fail-loud validation with concrete ranges + message format (see *Validation*). |
| GRID-04 | All model coefficients/weights live in the config/data file, editable without recompile. | `namelist /coeffs/` group with UHI weights + diurnal multipliers + baseline weather, loaded at runtime (see *Pattern: namelist*). Phase 1 only loads them; no physics uses them yet. |
</phase_requirements>

## Architectural Responsibility Map

This is a single-tier batch CLI program (no client/server/DB tiers). "Tier" maps to module layers from `ARCHITECTURE.md`.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Precision / kind definition | Foundation (`kinds_mod`) | — | One source of truth for `wp = real64` (D-09); used by all, uses nothing. |
| Named constants / fill values | Foundation (`constants_mod`) | `kinds_mod` | Validation bounds + missing/sentinel values live here, not scattered in code. |
| Cell & grid data structures | Data (`grid_mod`) | `kinds_mod` | `type(cell)`, `grid_t`, allocate/lifecycle. No I/O — pure types + helpers. |
| CSV + namelist loading, validation | I/O (`io_mod`) | `grid_mod`, `constants_mod` | All file reads + range checks here; returns `stat`/`msg` (never `error stop`). |
| Orchestration, fatal-exit policy, print grid | Driver (`app/main.f90`) | `io_mod`, `grid_mod` | Composition root: owns `iostat` handling, the one `error stop`, and the terminal echo. |

**Misassignment guard for the planner:** validation logic belongs in `io_mod` (data layer), the *decision to abort* belongs in `app/main.f90` (driver). Do not put `error stop` inside `io_mod` (it makes the loader untestable — see *Pattern 5* and *Testing*). Do not hard-code district values or grid dimensions in any module (PITFALL/anti-pattern: violates GRID-01).

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| gfortran (GCC) | 16.1.0 (Homebrew) — **verified installed** | Fortran compiler | De-facto free Fortran compiler; full F2018; strong runtime checks. `[VERIFIED: gfortran --version → GNU Fortran (Homebrew GCC 16.1.0)]` |
| fpm (Fortran Package Manager) | 0.13.0 | Build/test/run driver; auto-resolves module compile order | Eliminates the hand-ordered Makefile + stale-`.mod` class of bugs (PITFALL A3). `[VERIFIED: github.com/fortran-lang/fpm releases]` — **NOT installed yet** `[VERIFIED: command -v fpm → not found]` |
| `iso_fortran_env` | intrinsic | Portable `real64` kind | Self-documenting precision (D-09); already used by retired `numerics.f90`. `[VERIFIED: src/numerics.f90 uses real64]` |
| Fortran standard | F2018 (`-std=f2018`) | Language level | Fully supported by GCC 16; matches existing Makefile flags. `[CITED: .planning/research/STACK.md]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| test-drive | 0.6.0 | Unit testing under fpm | Add under `[dev-dependencies]`; run with `fpm test`. Use for the Phase-1 CSV/config round-trip + bad-row tests. `[CITED: STACK.md; github.com/fortran-lang/test-drive]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fpm | Plain GNU Makefile (the retired scaffold) | Honors zero-new-tools, but reintroduces hand-managed module order + stale-`.mod` heisenbugs (A3). D-08 locks fpm. |
| test-drive | Hand-rolled ~30-line `assert` module | Zero deps, fine for a learner; but D-08 adopts fpm and test-drive is the community default. Either is acceptable; test-drive recommended. |
| namelist for coefficients | TOML/JSON via a parser lib | Adds a dependency for no benefit; namelist is Fortran-native and D-01 locks it. |
| Manual comma-split CSV parse | List-directed `read(u,*)` of the whole row | List-directed read mis-handles multi-word district names ("District 1", "Can Gio") and gives no per-field line/column error → defeats fail-loud (D-07). Manual split is the right call. |

**Installation (execute-time, fpm not yet present):**
```bash
gfortran --version          # expect GCC 16.1.0 — already verified
brew install fpm            # REQUIRED: fpm is not installed yet
fpm --version               # confirm >= 0.13.0
```

**Version verification:** `gfortran` 16.1.0 confirmed via `gfortran --version` this session. `fpm` confirmed absent via `command -v fpm`. `brew` confirmed present. test-drive and fpm versions are from `STACK.md` (verified there against GitHub releases) — re-confirm `fpm --version` after install.

## Package Legitimacy Audit

> Fortran/fpm dependencies are **git-based**, not npm/PyPI/crates registry packages, so the `gsd-tools query package-legitimacy check` seam (which targets npm/pypi/crates) does not apply. Assessed manually against the official `fortran-lang` GitHub org.

| Package | Source | Age | Adoption | Source Repo | Verdict | Disposition |
|---------|--------|-----|----------|-------------|---------|-------------|
| fpm | Homebrew formula + github.com/fortran-lang/fpm | mature (1.0-track, v0.13.0 Feb 2026) | official Fortran-lang tool, de-facto standard | github.com/fortran-lang/fpm | OK | Approved (install via brew) |
| test-drive | git dep github.com/fortran-lang/test-drive | mature (v0.6.0) | community default test framework | github.com/fortran-lang/test-drive | OK | Approved (pin a tag in `[dev-dependencies]`) |

**Packages removed due to SLOP verdict:** none.
**Packages flagged as suspicious (SUS):** none.

**Recommendation:** pin test-drive to a tag (`tag = "v0.6.0"`) rather than tracking `main`, so the build is reproducible. fpm fetches and builds it on first `fpm test`; no manual install.

## Architecture Patterns

### System Architecture Diagram

```
  data/hcmc_districts.csv          data/model_coeffs.nml
  (one row per district)           (&coeffs ... / namelist)
          │                                 │
          ▼  io_mod%read_grid_csv           ▼  io_mod%read_coeffs
   [ line-buffered read ]            [ namelist read w/ defaults ]
   [ comma-split → fields ]          [ iostat / iomsg checked   ]
   [ per-field iostat parse ]                │
   [ range-validate each field ]             │
          │   returns (grid_t, stat, msg)    │  returns (coeffs_t, stat, msg)
          └───────────────┬──────────────────┘
                          ▼
              app/main.f90 (DRIVER / composition root)
              if (stat /= 0)  write(error_unit) msg ;  error stop 1
                          │  (validated grid_t + coeffs_t in memory)
                          ▼
              io_mod%print_grid(grid)   → terminal echo of loaded cells
                          ▼
                  exit 0   (Phase 1 ends: file → terminal round-trip)
```
Data flows downward only; physics/scenario/CSV-export stages (Phases 2–4) attach below `print_grid` later. The grid container `cells(:,:)` is a 2D raster; districts occupy `(i,j)` slots, empty slots carry `occupied = .false.`.

### Recommended Project Structure (fpm default layout)
```
fortran-fortress/
├── fpm.toml              # manifest: metadata, build, dev-deps, flag profiles
├── README.md             # update: document fpm build/run/test + flag profiles
├── app/
│   └── main.f90          # program uhi_sim — driver / composition root
├── src/
│   ├── kinds.f90         # kinds_mod      (wp = real64)
│   ├── constants.f90     # constants_mod  (validation bounds, sentinels)
│   ├── grid.f90          # grid_mod       (type(cell), grid_t, allocate)
│   └── io.f90            # io_mod         (read CSV, read namelist, validate, print)
├── test/
│   └── test_io.f90       # test-drive suite: valid load + malformed-row rejection
├── data/
│   ├── hcmc_districts.csv  # ~12–16 seed districts (D-05)
│   └── model_coeffs.nml    # &coeffs namelist (D-01/GRID-04)
└── build/                # fpm artifacts — gitignore
```
> **Layout note (deviation from ARCHITECTURE.md):** `ARCHITECTURE.md` placed `main.f90` in `src/` because it was written for the Makefile layout. Under **fpm**, `src/` is the *library* and the executable program lives in **`app/`** (auto-discovered). Put the driver in `app/main.f90`. `[CITED: fpm.fortran-lang.org/spec/manifest.html — default layout app/ src/ test/]`
>
> Phase 1 only needs `kinds`, `constants`, `grid`, `io` + driver. The physics modules (`heat_index`, `uhi`, `diurnal`, `scenario`, `summary`) from ARCHITECTURE.md are Phases 2–4 — do not create them now.

### Pattern 1: Foundation-first acyclic module stack
**What:** Each module `use`s only modules strictly lower in the stack: `kinds → constants → grid → io → main`. No cycles.
**When to use:** Always — fpm derives build order from `use`, and an acyclic graph guarantees a valid order exists. (This is what makes fpm "just work" vs. the retired Makefile's hand-ordered `OBJS`.)
**Example:**
```fortran
! Source: pattern from .planning/research/ARCHITECTURE.md + existing src/numerics.f90 idiom
module kinds_mod
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private
  integer, parameter, public :: wp = real64   ! working precision — one place
end module kinds_mod
```

### Pattern 2: `type(cell)` derived type + allocatable 2D `grid_t` raster
**What:** One district = `type(cell)`; the city = a 2D **allocatable** array of cells sized at runtime from the namelist extent. An `occupied` flag tolerates empty raster slots (D-04).
**When to use:** District-scale grids where clarity beats throughput (AoS).
**Example:**
```fortran
! Source: .planning/research/ARCHITECTURE.md (Pattern 2), adapted with (i,j) + occupied per D-03/D-04
module grid_mod
  use kinds_mod, only: wp
  implicit none
  private
  public :: cell, grid_t, allocate_grid

  type :: cell
    character(len=:), allocatable :: name      ! "District 1", "Can Gio"
    integer  :: i = 0, j = 0                   ! raster coordinates (1-based)
    real(wp) :: t_air     = 0.0_wp             ! air temperature (degC)
    real(wp) :: rh        = 0.0_wp             ! relative humidity (%)
    real(wp) :: water_km  = 0.0_wp             ! distance to river/ocean (km)
    real(wp) :: building  = 0.0_wp             ! building density 0..1
    real(wp) :: tree      = 0.0_wp             ! tree density 0..1
    logical  :: is_urban  = .true.             ! urban(1)/rural(0) class
    logical  :: occupied  = .false.            ! false = empty raster slot (D-04)
  end type cell

  type :: grid_t
    integer :: nx = 0, ny = 0                  ! extent from namelist (or derived)
    integer :: ndist = 0                       ! count of occupied districts
    type(cell), allocatable :: cells(:,:)      ! allocate(cells(nx,ny))
  end type grid_t
contains
  subroutine allocate_grid(g, nx, ny)
    type(grid_t), intent(out) :: g
    integer,      intent(in)  :: nx, ny
    g%nx = nx; g%ny = ny; g%ndist = 0
    allocate(g%cells(nx, ny))                  ! all default occupied = .false.
  end subroutine allocate_grid
end module grid_mod
```
**Trade-off:** AoS is slightly less SIMD-friendly than struct-of-arrays at large N, but irrelevant at ~12–16 cells. Designed pure-function-friendly for Phase 2 (no global state — see CONTEXT integration point).

### Pattern 3: `namelist` for coefficients with pre-seeded defaults
**What:** Declare a `namelist /coeffs/` group; set every variable to a default *before* the read, so a missing key in the file keeps its default and a malformed file is caught by `iostat`/`iomsg`.
**When to use:** All of GRID-04. Namelist is Fortran-native (D-01) — zero parser code.
**Example:**
```fortran
! Source: Fortran 2018 namelist semantics (curated); group/var names are Claude's discretion
module io_mod
  use kinds_mod, only: wp
  implicit none
  ! ... in the read routine:
  real(wp) :: w_build, w_urban, w_tree, w_water
  real(wp) :: m_morning, m_afternoon, m_evening, m_predawn   ! diurnal multipliers
  real(wp) :: t_base, rh_base                                ! baseline weather
  integer  :: nx, ny                                         ! grid extent (D-04)
  namelist /coeffs/ w_build, w_urban, w_tree, w_water,        &
                    m_morning, m_afternoon, m_evening, m_predawn, &
                    t_base, rh_base, nx, ny
  ! set defaults FIRST so missing keys are tolerated:
  w_build = 3.0_wp; w_urban = 1.0_wp; w_tree = 2.5_wp; w_water = 2.0_wp
  m_morning = 0.5_wp; m_afternoon = 0.3_wp; m_evening = 0.8_wp; m_predawn = 1.0_wp
  t_base = 28.0_wp; rh_base = 78.0_wp; nx = 0; ny = 0
  open(newunit=u, file=path, status='old', action='read', iostat=ios, iomsg=msg)
  if (ios /= 0) then; stat = ios; return; end if
  read(u, nml=coeffs, iostat=ios, iomsg=msg)   ! iomsg carries the parse error
  close(u)
  if (ios /= 0) then; stat = ios; return; end if
```
Namelist **file** (`data/model_coeffs.nml`):
```
&coeffs
  w_build = 3.0, w_urban = 1.0, w_tree = 2.5, w_water = 2.0
  m_morning = 0.5, m_afternoon = 0.3, m_evening = 0.8, m_predawn = 1.0
  t_base = 28.0, rh_base = 78.0
  nx = 8, ny = 10
/
```
> Default-weight values are illustrative starting points from `FEATURES.md §2` — Phase 1 only needs them to *load*, not to be tuned (tuning is deferred). `[CITED: .planning/research/FEATURES.md]`

### Pattern 4: Status-flag error handling — loader returns `stat`/`msg`, driver aborts
**What:** `io_mod` routines take `intent(out) :: stat` (integer) and `intent(out) :: msg` (character) and **return** on any error. Only `app/main.f90` decides to `error stop`.
**When to use:** All of `io_mod`. This is what makes the malformed-row behavior (D-07) **unit-testable** — a test asserts a bad fixture yields `stat /= 0` and an expected message, instead of the loader killing the test process.
**Example:**
```fortran
! Source: .planning/research/ARCHITECTURE.md (Pattern 5)
! in app/main.f90 (the ONLY place error stop lives):
call read_grid_csv('data/hcmc_districts.csv', coeffs%nx, coeffs%ny, grid, stat, msg)
if (stat /= 0) then
   write(error_unit, '(A)') trim(msg)
   error stop 1
end if
```

### Anti-Patterns to Avoid
- **`error stop` inside `io_mod`:** un-testable; aborts the test runner. Return `stat`/`msg` instead (Pattern 4).
- **Hard-coded grid dimensions / district values in source:** violates GRID-01/D-02; read everything from `data/`. (ARCHITECTURE anti-pattern 2.)
- **List-directed `read(u,*) name, i, j, ...` for the CSV row:** breaks on multi-word names and gives no per-field error → defeats fail-loud (D-07). Use the line-buffer + comma-split pattern (Code Examples).
- **Relying on `fpm build --profile release` defaults:** injects `-ffast-math`/`-march=native` — forbidden (see *Pitfall 1*).
- **Integer-typed grid attributes:** store all numeric fields as `real(wp)` even when the CSV holds whole numbers; convert at load (PITFALL A2 integer division).
- **Initializing accumulators in a declaration** (`integer :: n = 0` inside a routine): gives the `save` attribute → not reset on re-call (PITFALL A5). Initialize in the executable body.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Module compile ordering | A hand-ordered Makefile `OBJS` list (the retired scaffold) | `fpm` auto-resolution | The #1 hand-Makefile pain + stale-`.mod` heisenbugs (A3). D-08. |
| Coefficient config parsing | A bespoke key=value parser | Fortran `namelist` | Native, zero code, edit-without-recompile (D-01/GRID-04). |
| CSV *writing* (later phases) | A CSV library | Formatted `write` with `F0.x`/`g0` | One statement; lib is pure overhead (STACK "What NOT to Use"). |
| Reductions (later) | Triple-nested loops | `sum`/`maxval`/`maxloc`/`count`/`pack` intrinsics | Fewer bugs, vectorized. |
| Precision plumbing | Magic `kind=8` | `real64` from `iso_fortran_env` in `kinds_mod` | One knob; self-documenting (D-09). |

**Key insight:** Almost everything Phase 1 needs is in the standard language + fpm. The *only* code you genuinely write is the ~30–50-line CSV line-parser/validator — and even that is "split on commas + per-field `read` with `iostat`," not a real parser. No external library beyond test-drive.

## Runtime State Inventory

> This phase retires the Hello-World scaffold and switches build systems, so stale build artifacts matter (PITFALL A3). Greenfield otherwise — no databases, services, or secrets.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastores in this project. | None. |
| Live service config | None — self-contained CLI, no external services. | None. |
| OS-registered state | None — no scheduled tasks/daemons. | None. |
| Secrets/env vars | None — no secrets; data files are public seed values. | None. |
| Build artifacts | `build/` currently holds Makefile-era artifacts (`numerics.mod`, `numerics.o`, `main.o`, `fortress` binary). Stale `.mod` from the old layout can shadow the new modules (A3). `[VERIFIED: ls build/]` | **Delete `build/` before first fpm build** (`rm -rf build`); add `build/` (+ `*.mod`, `*.o`) to `.gitignore` — currently only `.vscode` is ignored `[VERIFIED: cat .gitignore]`. |
| Files to retire (D-08) | `Makefile`, `src/numerics.f90`, `src/main.f90` all exist. `[VERIFIED: ls + reads]` | `git rm` them as part of the fpm cutover. The `dp = real64` / `pure function` idiom in `numerics.f90` is reusable as the basis for `kinds_mod` (CONTEXT reusable asset) — copy the *pattern*, delete the *file*. |

## Common Pitfalls

### Pitfall 1: fpm's built-in `release` profile injects forbidden flags
**What goes wrong:** Running `fpm build --profile release` compiles gfortran with the built-in default `-O3 -march=native -ffast-math -funroll-loops`. `-ffast-math` breaks IEEE semantics (can mask/produce NaNs — undermines "believable numbers"); `-march=native` is an x86 idiom that is the wrong tuning knob on Apple-Silicon aarch64 and can warn/error. Both are explicitly forbidden by STACK.md and PITFALLS. `[ASSUMED: fpm default gfortran release flags — confirm at execute time]`
**Why it happens:** fpm ships optimized defaults aimed at HPC, not at IEEE-reproducible illustrative models; and `--profile release` is the obvious command to reach for.
**How to avoid:** **Do not inherit the built-in release flags.** Define the project's own explicit dev and release flag sets (see *Validation Architecture → fpm flag profiles* below) and **verify the actual compile line** at execute time with `fpm build --verbose` (it echoes the gfortran invocation) — confirm it shows `-O2 -std=f2018 -fimplicit-none -Wall` for release and the strict D-09 set for dev, with **no** `-ffast-math` / `-march=native`.
**Warning signs:** `--verbose` shows `-ffast-math` or `-march=native`; release numbers differ from `-O0` debug numbers beyond rounding; aarch64 tuning warnings.

### Pitfall 2: Multi-word district names defeat list-directed reads
**What goes wrong:** "District 1", "Can Gio", "Thu Duc", "Binh Thanh" contain spaces. `read(u,*) name, i, j, ...` reads only "District" into `name`, then tries to parse "1" as `i` and silently column-shifts every field after — a *scientific* error caused by an *I/O* bug (PITFALL A10).
**Why it happens:** List-directed input treats whitespace as a separator.
**How to avoid:** Treat the **first comma-delimited field** as the whole name (spaces allowed, no quoting needed). Read the line into a buffer, split on commas by `index()`, take field 1 verbatim as the name, internal-`read` the remaining fields individually (Code Examples).
**Warning signs:** Values shifted by one column; `i`/`j` parse errors on otherwise-valid rows; densities landing in the temperature field.

### Pitfall 3: Missing per-field `iostat` → no line/column in the error
**What goes wrong:** A single `read` of the whole row with one `iostat` can tell you the row failed but not *which field* or *why*, so the D-07 message can't name the reason precisely.
**Why it happens:** One `iostat` covers the whole list-directed statement.
**How to avoid:** Internal-`read` each numeric field separately with its own `iostat`; on failure report `file:line` + the field name + the offending substring. Then range-check each parsed value against `constants_mod` bounds and report the first violation.
**Warning signs:** Errors say "bad row 12" with no field/reason; users can't tell a column-count bug from a bad number.

### Pitfall 4: Stale `.mod` / leftover Makefile `build/` shadows the fpm build (A3)
**What goes wrong:** The old `build/` dir (with `numerics.mod` etc.) or a half-migrated tree lets a dependent file compile against a stale interface, producing wrong behavior that only a clean rebuild fixes.
**How to avoid:** `rm -rf build` before the first `fpm build`; ensure `Makefile`/`src/numerics.f90`/`src/main.f90` are removed so fpm can't pick them up; gitignore `build/`. Verify a clean `fpm build && fpm run && fpm test` from scratch.
**Warning signs:** "Cannot open module file"; behavior changes after a clean rebuild; fpm compiles `numerics.f90` you thought was deleted.

### Pitfall 5: Default-real literals silently drop precision (A1)
**What goes wrong:** `0.5`, `100.0`, `9.0/5.0` are single precision even when assigned to `real(wp)`; arithmetic happens in 32-bit then widens.
**How to avoid:** Suffix **every** real literal `_wp` (validation bounds, defaults, conversions). The existing `numerics.f90` already models this (`0.5_dp`, `PI ...826_dp`). Keep `-finit-real=snan` in the dev profile to surface uninitialized reads.
**Warning signs:** Numbers shift between `-O0` and `-O2`; `-fdefault-real-8` changes output (diagnostic only).

## Code Examples

### CSV row read with line number, comma-split, per-field `iostat`, range-validate
```fortran
! Source: synthesized from ARCHITECTURE.md Pattern 5 + PITFALLS A10/A2/A9 + Fortran 2018 internal-read semantics
! Reads data/hcmc_districts.csv: header row, then rows of:
!   name,i,j,t_air,rh,water_km,building,tree,urban     (urban = 1 or 0)
subroutine read_grid_csv(path, nx, ny, g, stat, msg)
  use kinds_mod,      only: wp
  use grid_mod,       only: grid_t, allocate_grid
  use constants_mod,  only: T_MIN, T_MAX, RH_MIN, RH_MAX, DEN_MIN, DEN_MAX
  character(len=*), intent(in)  :: path
  integer,          intent(in)  :: nx, ny
  type(grid_t),     intent(out) :: g
  integer,          intent(out) :: stat
  character(len=*), intent(out) :: msg

  integer, parameter :: NFIELD = 9
  character(len=512) :: line
  character(len=64)  :: fld(NFIELD)
  integer :: u, ios, lineno, nf, ii, jj, urb
  real(wp) :: t, rh, wkm, bld, tre

  stat = 0; msg = ''
  call allocate_grid(g, nx, ny)
  open(newunit=u, file=path, status='old', action='read', iostat=ios, iomsg=msg)
  if (ios /= 0) then; stat = ios; return; end if

  lineno = 0
  read(u, '(A)', iostat=ios) line          ! consume header row
  lineno = lineno + 1
  do
     read(u, '(A)', iostat=ios) line
     if (ios /= 0) exit                     ! end of file
     lineno = lineno + 1
     if (len_trim(line) == 0) cycle         ! skip blank lines
     if (line(1:1) == '#')    cycle         ! skip comments

     call split_commas(line, fld, nf)       ! helper: fills fld(:), sets nf
     if (nf /= NFIELD) then
        write(msg,'(A,I0,A,I0,A,I0)') trim(path)//':', lineno, &
             ': expected ', NFIELD, ' fields, got ', nf
        stat = 1; close(u); return
     end if

     ! --- per-field parse, each with its own iostat (Pitfall 3) ---
     read(fld(2),*,iostat=ios) ii;  if (ios/=0) call fail('i (col 2)')
     read(fld(3),*,iostat=ios) jj;  if (ios/=0) call fail('j (col 3)')
     read(fld(4),*,iostat=ios) t;   if (ios/=0) call fail('t_air (col 4)')
     read(fld(5),*,iostat=ios) rh;  if (ios/=0) call fail('rh (col 5)')
     read(fld(6),*,iostat=ios) wkm; if (ios/=0) call fail('water_km (col 6)')
     read(fld(7),*,iostat=ios) bld; if (ios/=0) call fail('building (col 7)')
     read(fld(8),*,iostat=ios) tre; if (ios/=0) call fail('tree (col 8)')
     read(fld(9),*,iostat=ios) urb; if (ios/=0) call fail('urban (col 9)')
     if (stat /= 0) then; close(u); return; end if

     ! --- range validation (Validation section) ---
     if (ii < 1 .or. ii > nx) call range_fail('i', real(ii,wp), 1.0_wp, real(nx,wp))
     if (jj < 1 .or. jj > ny) call range_fail('j', real(jj,wp), 1.0_wp, real(ny,wp))
     if (t  < T_MIN  .or. t  > T_MAX ) call range_fail('t_air',    t,   T_MIN,  T_MAX)
     if (rh < RH_MIN .or. rh > RH_MAX) call range_fail('rh',       rh,  RH_MIN, RH_MAX)
     if (wkm < 0.0_wp)                 call range_fail('water_km', wkm, 0.0_wp, huge(0.0_wp))
     if (bld < DEN_MIN .or. bld > DEN_MAX) call range_fail('building', bld, DEN_MIN, DEN_MAX)
     if (tre < DEN_MIN .or. tre > DEN_MAX) call range_fail('tree',     tre, DEN_MIN, DEN_MAX)
     if (urb /= 0 .and. urb /= 1) call range_fail('urban', real(urb,wp), 0.0_wp, 1.0_wp)
     if (g%cells(ii,jj)%occupied) call fail('duplicate (i,j) cell')
     if (stat /= 0) then; close(u); return; end if

     ! --- commit (store ALL numeric as real(wp); urban int -> logical) ---
     g%cells(ii,jj)%name     = trim(adjustl(fld(1)))
     g%cells(ii,jj)%i = ii;  g%cells(ii,jj)%j = jj
     g%cells(ii,jj)%t_air    = t
     g%cells(ii,jj)%rh       = rh
     g%cells(ii,jj)%water_km = wkm
     g%cells(ii,jj)%building = bld
     g%cells(ii,jj)%tree     = tre
     g%cells(ii,jj)%is_urban = (urb == 1)
     g%cells(ii,jj)%occupied = .true.
     g%ndist = g%ndist + 1
  end do
  close(u)
contains
  subroutine fail(what)
    character(len=*), intent(in) :: what
    write(msg,'(A,I0,A)') trim(path)//':', lineno, ': cannot parse '//trim(what)
    stat = 1
  end subroutine fail
  subroutine range_fail(name, val, lo, hi)
    character(len=*), intent(in) :: name
    real(wp),         intent(in) :: val, lo, hi
    write(msg,'(A,I0,5A)') trim(path)//':', lineno, ': ', trim(name), &
         ' out of range'   ! (append val/lo/hi with F0.2 edit descriptors as desired)
    stat = 1
  end subroutine range_fail
end subroutine read_grid_csv
```
> `split_commas` is a ~10-line helper: scan the buffer, copy substrings between commas into `fld(:)`, count them. (Trivial; the planner can inline it or give it its own small task.) The `range_fail` message can be enriched with the actual value/bounds using `F0.2` descriptors — keep `F0.x` (never fixed-width `F6.2`) to avoid `*****` overflow (A9).

### kinds_mod (reuses the retired numerics.f90 idiom)
```fortran
! Source: src/numerics.f90 (existing, lines 3-9) — pattern reused, file retired
module kinds_mod
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private
  integer, parameter, public :: wp = real64
end module kinds_mod
```

### constants_mod (validation bounds live here, not in io_mod)
```fortran
! Source: bounds chosen from FEATURES.md HCMC envelope + D-07 ranges
module constants_mod
  use kinds_mod, only: wp
  implicit none
  private
  real(wp), parameter, public :: T_MIN  = 10.0_wp, T_MAX  = 50.0_wp   ! degC plausible band
  real(wp), parameter, public :: RH_MIN =  0.0_wp, RH_MAX = 100.0_wp  ! %
  real(wp), parameter, public :: DEN_MIN = 0.0_wp, DEN_MAX = 1.0_wp   ! fractional density
end module constants_mod
```

## Validation Architecture

> `workflow.nyquist_validation` is **false** `[VERIFIED: .planning/config.json]`, so the formal Nyquist test-mapping section is **omitted**. The lightweight Phase-1 test approach is documented here instead (the roadmap's plan 01-04 calls for a "config read round-trip test").

### fpm flag profiles (operationalizing D-09) — the load-bearing setup detail

fpm gives two flag-customization mechanisms; the project needs **exact** flag sets and must **not** inherit the harmful built-in release defaults (Pitfall 1). The cleanest, most portable approach is to **define the flags explicitly** and **verify the actual compile line** after install.

**Required flag sets (D-09 + STACK.md):**
- **dev/debug:** `-g -O0 -std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan`
- **release:** `-O2 -std=f2018 -fimplicit-none -Wall`  (NO `-O3`, NO `-ffast-math`, NO `-march=native`)

**Two ways to apply them (pick per what the installed fpm version supports — VERIFY at execute time):**

1. **Manifest profiles (preferred, declarative).** Per fpm docs, when you define `debug`/`release` in the manifest your definitions *replace* the built-in defaults — exactly what's wanted. `[CITED: fpm.fortran-lang.org/spec/features.html]` Candidate TOML (⚠️ exact key path varies between fpm generations — confirm against the *installed* version's `spec/manifest.html`):
   ```toml
   # one candidate form — verify with: fpm build --verbose
   [profiles.release.gfortran]
   flags = "-O2 -std=f2018 -fimplicit-none -Wall"
   [profiles.debug.gfortran]
   flags = "-g -O0 -std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan"
   ```
2. **Command-line `--flag` (guaranteed-portable fallback).** Works on every fpm version; document the commands in the README:
   ```bash
   fpm build --flag "-g -O0 -std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan"
   fpm run   --profile release --flag "-O2 -std=f2018 -fimplicit-none -Wall"
   ```
   Note: `--flag` *appends* to the selected profile's flags, so for release prefer the manifest form (or accept the default debug profile + explicit `--flag` for dev). The manifest form is cleaner; the `--flag` form is the safety net.

> **Planner action:** add an execute-time **checkpoint** after `brew install fpm`: run `fpm build --verbose`, read the echoed gfortran command, and confirm the flags match the sets above with no `-ffast-math`/`-march=native`. If the manifest `[profiles.*]` syntax differs in the installed version, fall back to `--flag` and adjust.

### Test approach (lightweight, test-drive under fpm)
| Property | Value |
|----------|-------|
| Framework | test-drive 0.6.0 via `[dev-dependencies]` (pin `tag = "v0.6.0"`) |
| Run command | `fpm test` |
| Fixtures | tiny `test/fixtures/*.csv` (one valid, one malformed) committed alongside the test |

**Phase-1 tests (map to GRID-01..04):**
1. **Valid round-trip (GRID-01/02/03):** load a small known CSV → assert `g%ndist` == expected, and a couple of cells have the expected `real(wp)` field values and correct `is_urban`. Proves file→struct and that numeric fields are stored as reals.
2. **Malformed-row rejection (GRID-03/D-07):** feed a fixture with (a) a short row, (b) an unparseable number, (c) RH = 142, (d) a duplicate `(i,j)` → assert `stat /= 0` and that `msg` contains the line number. *This is why the loader returns `stat`/`msg` instead of `error stop` (Pattern 4) — otherwise the test process dies.*
3. **Coefficient load (GRID-04):** load a known `.nml` → assert the weights/multipliers/extent match; load a `.nml` missing a key → assert defaults are retained.

**Phase gate (manual, since nyquist off):** `rm -rf build && fpm build && fpm run && fpm test` all clean from a fresh checkout; running `fpm run` prints the loaded grid; editing a value in `data/hcmc_districts.csv` and re-running `fpm run` (no rebuild of changed *source*) changes the printed output (GRID-01 proof).

## Seed Data (GRID-03 / D-05) — concrete values from FEATURES.md

Ship ~12–16 rows covering the five archetypes + recognizable districts. Suggested CSV schema (column order is Claude's discretion — this is one concrete proposal):

```
# name,i,j,t_air,rh,water_km,building,tree,urban     (urban: 1=urban 0=rural)
District 1,4,5,33.0,75,1.0,0.85,0.10,1
District 3,4,6,32.5,76,2.5,0.80,0.12,1
District 5,3,5,32.8,77,1.5,0.82,0.08,1
District 10,4,7,32.6,76,3.0,0.78,0.10,1
District 7,5,4,31.5,80,0.8,0.60,0.25,1
Binh Thanh,5,6,32.4,76,1.2,0.72,0.15,1
Tan Binh,3,7,32.9,74,5.0,0.80,0.10,1
Go Vap,3,8,32.7,75,6.0,0.75,0.12,1
Thu Duc Industrial,6,7,34.5,72,4.0,0.92,0.03,1
Binh Tan Industrial,2,6,34.2,72,7.0,0.90,0.04,1
Tao Dan Park,4,5,30.5,80,1.5,0.20,0.70,1
Can Gio,7,1,29.0,88,0.2,0.05,0.85,0
Cu Chi Rural Fringe,1,9,30.0,82,9.0,0.15,0.55,0
Nha Be Peri-urban,6,3,30.8,83,0.5,0.30,0.45,0
```
> Archetype mapping per `FEATURES.md §HCMC Baselines`: District 1 / industrial zones = hot urban; Tao Dan = park cool-island; Can Gio = coastal/mangrove coolest control; Cu Chi / Nha Be = rural/peri-urban references. Air-temp 29–35 °C, RH 72–88% sit inside the HCMC envelope. `[CITED: .planning/research/FEATURES.md]` Values are **illustrative seed data**, not measured — the file header should say so. `(i,j)` coordinates are an approximate layout; Tao Dan shares a slot region with District 1 conceptually but must occupy a *distinct* `(i,j)` (duplicate-cell validation will reject collisions — assign unique coords). Pick `nx`/`ny` in the namelist to bound all coordinates (e.g. `nx=8, ny=10`).

## Security Domain

> `security_enforcement` is **true**, ASVS level 1 `[VERIFIED: .planning/config.json]`. This is a **local, offline, single-user batch CLI** that reads local text files it ships with — no network, no auth, no users, no persistence, no secrets. Most ASVS categories are structurally N/A; the one that genuinely applies is **input validation**, which is already the phase's headline requirement (D-07).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No identities/credentials in an offline CLI. |
| V3 Session Management | no | No sessions. |
| V4 Access Control | no | Single local user; OS file permissions only. |
| V5 Input Validation | **yes** | Fail-loud per-field parse + range validation of every CSV field and namelist key (D-07) — see *Validation* + *Code Examples*. Bounded fixed-length buffers (`character(len=512)`) guard against overlong lines. |
| V6 Cryptography | no | No secrets or crypto. |
| V7 Error Handling & Logging | **yes (light)** | Errors go to `error_unit` with a precise `file:line: reason`; no sensitive data to leak. Non-zero exit (`error stop 1`) on failure. |
| V12 File Resources | **yes (light)** | Data file path comes from the program (or a CLI arg later), not untrusted remote input; `status='old', action='read'` (read-only). |

### Known Threat Patterns for a Fortran file-loader
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed/oversized input row → silent column-shift or buffer issue | Tampering | Per-field `iostat` + field-count check + bounded `character(len=512)` line buffer; fail loud (D-07). |
| Out-of-range value → NaN/garbage propagating into later physics | Tampering | Range-validate at load against `constants_mod` bounds; `-ffpe-trap=invalid,zero,overflow` in dev (A5/A9). |
| Out-of-bounds raster write (`cells(i,j)` with bad `i,j`) | Tampering / DoS | Validate `i∈[1,nx]`, `j∈[1,ny]` *before* indexing; develop with `-fcheck=all` (A6). |
| Duplicate `(i,j)` overwriting a cell | Tampering | Reject duplicates with a loud line-numbered error. |

**Net:** the security posture for Phase 1 is satisfied by doing D-07 well plus the strict dev flags. No additional security tasks needed beyond what GRID-03/D-07 already mandate. `security_block_on` is `high`; no high-severity issues identified.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gfortran | compile everything | ✓ | GCC 16.1.0 (Homebrew) | — |
| Homebrew (`brew`) | install fpm | ✓ | present | download fpm release binary from github.com/fortran-lang/fpm/releases |
| fpm | build/run/test (D-08) | ✗ | — | **must install** via `brew install fpm` before any build; no viable Makefile fallback since D-08 retires it |
| test-drive | `fpm test` | ✗ (fetched by fpm) | 0.6.0 | hand-rolled `assert` module (~30 lines) if the git fetch is unavailable offline |

**Missing dependencies with no fallback:**
- **fpm** — blocking. First execute-time task must be `brew install fpm` (and `fpm --version` ≥ 0.13.0). All build/run/test success criteria depend on it.

**Missing dependencies with fallback:**
- **test-drive** — fpm fetches it from git on first `fpm test`; if the environment is offline, substitute a tiny hand-rolled assert program in `test/` (STACK.md sanctions this).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-ordered GNU Makefile (`OBJS := numerics.o main.o`) — the existing scaffold | fpm auto-resolves module order from `use` | fpm matured (v0.13.0, Feb 2026) | Phase 1 retires the Makefile (D-08); eliminates A3 stale-`.mod` class of bugs. |
| `kind=8` magic numbers | `real64` from `iso_fortran_env` in one `kinds_mod` | modern Fortran standard practice | D-09; already used by `numerics.f90`. |
| Fixed-width output descriptors (`F6.2`) | `F0.x` / `g0` width-free | community best practice | Avoids `*****` overflow (A9) — relevant in Phase 4, set the habit now. |

**Deprecated/outdated for this project:**
- The retired `Makefile`, `src/numerics.f90`, `src/main.f90` (D-08) — delete, keep only the `dp=real64` *pattern*.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | fpm's built-in gfortran `release` profile = `-O3 -march=native -ffast-math -funroll-loops` | Pitfall 1 | If the actual defaults are benign, the warning is overcautious — but the mitigation (define explicit flags + verify with `--verbose`) is correct either way, so risk is low. |
| A2 | Manifest `[profiles.release.gfortran] flags = "..."` is the correct key path to override flags in the installed fpm | Validation Architecture | If the syntax differs in fpm 0.13.0, the manifest profile is ignored/errors. Mitigated by the `--flag` fallback + the mandatory `fpm build --verbose` verification checkpoint. |
| A3 | Defining `debug`/`release` in the manifest *replaces* (not extends) fpm's built-in defaults | Validation Architecture | If it instead *extends*, `-ffast-math` could sneak back in. The `--verbose` check catches this. |
| A4 | `--flag` *appends* to the selected profile's flags | Validation Architecture | If it replaces, the release `--flag` form is actually cleaner than stated — no downside. |
| A5 | Default-weight / baseline values (w_build=3.0, t_base=28, etc.) are reasonable seeds | Pattern 3 / Seed Data | Phase 1 only needs them to *load*; tuning is explicitly deferred (CONTEXT). No risk this phase. |

**Note:** A1–A4 all converge on the same safe action — *do not trust fpm flag defaults; set them explicitly and confirm with `fpm build --verbose` at execute time*. The planner should encode that verification as a checkpoint task.

## Open Questions (RESOLVED)

> **RESOLVED:** Each open question below is resolved for planning — every Recommendation has
> been adopted by the Phase 1 plans. Question 1 carries a residual MEDIUM-confidence risk
> (exact manifest key path in the installed fpm) deliberately deferred to 01-01's blocking
> `fpm build --verbose` checkpoint with a documented `--flag` fallback; Questions 2 and 3 are
> fully settled.

1. **RESOLVED — Exact fpm.toml profile/flag syntax for the installed version**
   - What we know: fpm supports per-profile per-compiler flag overrides; built-in `debug`/`release` exist; `--flag` works everywhere.
   - What's unclear: the precise TOML key path in fpm 0.13.0 (`[profiles.release.gfortran]` vs a newer `[features]`+`[profiles]` model the docs site describes).
   - Recommendation: hand-write the manifest with the `[profiles.*.gfortran]` form, then **verify with `fpm build --verbose`** immediately after `brew install fpm`; fall back to documented `--flag` commands if the manifest form is rejected.

2. **Grid extent: namelist-authoritative vs data-derived (D-04 allows either)**
   - What we know: D-04 permits both.
   - Recommendation: make the **namelist** authoritative (`nx`, `ny` in `&coeffs`), and validate each row's `(i,j)` against it — this gives a clean bound for the raster allocation and a precise "out of extent" error. Simpler than a two-pass max-scan of the CSV.

3. **CLI arg for data-file paths vs hard-coded `data/...`**
   - What we know: GRID-01 needs editability, not necessarily a configurable path.
   - Recommendation: hard-code `data/hcmc_districts.csv` and `data/model_coeffs.nml` for Phase 1 (simplest); accepting an optional CLI override is a trivial later add and not required.

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` — fpm 0.13.0, test-drive 0.6.0, gfortran flag profiles, namelist + delimited-read input, formatted-write output, "What NOT to Use" (no `-ffast-math`/`-march=native`).
- `.planning/research/ARCHITECTURE.md` — module decomposition, `type(cell)`/`grid_t`, allocatable grid, acyclic build order, Pattern 5 status-flag error handling, testing strategy.
- `.planning/research/PITFALLS.md` — A1 precision literals, A2 integer division, A3 stale `.mod`, A5 uninitialized locals, A6 bounds/1-based, A9 CSV formatting, A10 input-parsing/validation.
- `.planning/research/FEATURES.md` — HCMC baselines + district archetypes (seed values, ranges).
- `gfortran --version` → GNU Fortran (Homebrew GCC 16.1.0); `command -v fpm` → absent; `brew` present; `ls build/` stale artifacts; `cat .gitignore` → only `.vscode` — all verified this session.
- `src/numerics.f90` — existing `dp = real64` kind/module idiom (reusable pattern for `kinds_mod`).
- fpm manifest reference — `https://fpm.fortran-lang.org/spec/manifest.html` (default `app/`–`src/`–`test/` layout, `[[executable]]`/`[[test]]`/`[dev-dependencies]` syntax).

### Secondary (MEDIUM confidence)
- fpm features/profiles reference — `https://fpm.fortran-lang.org/spec/features.html` (custom flag profiles; manifest definitions replace built-in defaults). Exact key path version-sensitive → gated by execute-time `fpm build --verbose` check.

### Tertiary (LOW confidence)
- fpm built-in release default flags (`-O3 -march=native -ffast-math -funroll-loops`) — training knowledge, `[ASSUMED]`; the mitigation does not depend on the exact value.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — gfortran verified locally; fpm/test-drive versions verified in STACK.md against GitHub releases.
- Architecture / module decomposition: HIGH — stable Fortran language idioms, directly from ARCHITECTURE.md.
- CSV/namelist loading + validation: HIGH — standard F2018 I/O semantics; pattern synthesized from PITFALLS A10/A2/A9.
- fpm flag-profile TOML syntax: MEDIUM — concept HIGH, exact manifest key path version-sensitive (gated by a verification checkpoint).
- Seed data values: MEDIUM/HIGH — from FEATURES.md HCMC envelope; illustrative, not measured (and tuning is deferred).

**Research date:** 2026-06-28
**Valid until:** 2026-07-28 (stable Fortran/fpm ecosystem; re-confirm fpm.toml profile syntax against the version `brew install fpm` actually installs).
