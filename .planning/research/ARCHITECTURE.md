# Architecture Research

**Domain:** Modern Fortran scientific-computing program (2D grid simulation, batch CSV output)
**Researched:** 2026-06-28
**Confidence:** HIGH

> Scope: how to structure a modern Fortran (free-form, `implicit none`, `real64`)
> urban-heat-island simulator for clarity, testability, and correct gfortran build
> ordering. These are stable, well-established Fortran language facts and idioms, not
> volatile library choices — hence HIGH confidence.

## Standard Architecture

The program is a **batch pipeline**, not a service: read input once, run a nested sweep
of physics kernels over a grid, write results, exit. The idiomatic Fortran shape is a
**thin `program` driver** orchestrating a **stack of single-responsibility `module`s**,
ordered from foundational (no dependencies) at the bottom to application logic at the top.

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  DRIVER LAYER                                                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  program uhi_sim  (src/main.f90)                                │   │
│  │  parse args/config path → call scenario_runner → print summary  │   │
│  └───────────────┬──────────────────────────────┬─────────────────┘   │
├──────────────────┼──────────────────────────────┼─────────────────────┤
│  APPLICATION LAYER (orchestration over the grid)                       │
│  ┌───────────────▼───────────────┐   ┌──────────▼──────────────────┐   │
│  │  scenario_mod                 │   │  summary_mod (optional)     │   │
│  │  loop scenarios × timesteps;  │   │  reductions: hottest/coolest│   │
│  │  apply scenario mutations     │   │  city avg, urban–rural gap  │   │
│  └───┬──────────┬────────────┬───┘   └─────────────────────────────┘   │
├──────┼──────────┼────────────┼─────────────────────────────────────────┤
│  DOMAIN / PHYSICS LAYER (pure kernels, no I/O)                          │
│  ┌───▼──────┐  ┌▼──────────┐  ┌▼──────────────┐                        │
│  │heat_index│  │ uhi_mod   │  │ diurnal_mod   │   ← all pure/elemental  │
│  │ _mod     │  │ UHI offset│  │ time-of-day   │                        │
│  └──────────┘  └───────────┘  └───────────────┘                        │
├────────────────────────────────────────────────────────────────────────┤
│  DATA / I/O LAYER                                                       │
│  ┌──────────────────────┐   ┌──────────────────────────────────────┐   │
│  │ io_mod               │   │ grid_mod  (derived types + helpers)  │   │
│  │ read config/grid CSV │   │ type(cell), type(grid_t), allocate  │   │
│  │ write results CSV    │   │ accessors, allocate/deallocate       │   │
│  └──────────────────────┘   └──────────────────────────────────────┘   │
├────────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER (no project dependencies)                            │
│  ┌──────────────┐                ┌───────────────────────────────────┐  │
│  │ kinds_mod    │  ←──────────── │ constants_mod                     │  │
│  │ wp = real64  │   uses kinds   │ physical consts, model coefficients│ │
│  └──────────────┘                └───────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘

Dependency arrows point DOWNWARD only (upper layers use lower layers).
No upward or cyclic `use` — that is what makes the build order linear.
```

### Component Responsibilities

| Module (file) | Responsibility | Key contents |
|---------------|----------------|--------------|
| `kinds_mod` (`kinds.f90`) | Single source of truth for precision | `integer, parameter :: wp = real64` (alias `dp`), exported from `iso_fortran_env` |
| `constants_mod` (`constants.f90`) | Named physical constants & model coefficients | Heat-index regression coeffs, UHI weights (building/tree/water), urban/rural deltas, fill/missing values |
| `grid_mod` (`grid.f90`) | Derived types + grid lifecycle | `type :: cell`, `type :: grid_t`, `allocate_grid`, `deallocate_grid`, accessors/derived getters |
| `heat_index_mod` (`heat_index.f90`) | Apparent-temperature physics | `elemental pure function heat_index(t_air, rh)` — no I/O, no state |
| `uhi_mod` (`uhi.f90`) | UHI offset model | `elemental pure function uhi_offset(building, tree, water_dist, is_urban)` |
| `diurnal_mod` (`diurnal.f90`) | Time-of-day modulation | `elemental pure function diurnal_factor(hour, is_urban)` — drives the night-gap behavior |
| `scenario_mod` (`scenario.f90`) | What-if orchestration | `type :: scenario_t`, `apply_scenario(grid, scen)`, `run_scenario(...) -> results` |
| `summary_mod` (`summary.f90`) | Reductions for the terminal report | hottest/coolest cell, `sum`/`count` averages, urban–rural gap |
| `io_mod` (`io.f90`) | All file/console I/O | `read_grid_config`, `read_scenarios`, `write_results_csv`, `print_summary` |
| `program uhi_sim` (`main.f90`) | Composition root | wire path → io → scenario_runner → io/summary; owns `iostat` handling and exit codes |

**Hard boundary rule:** physics modules (`heat_index_mod`, `uhi_mod`, `diurnal_mod`) do
**no I/O and hold no module-level mutable state**. They take numbers in and return
numbers out. This is what makes them trivially unit-testable and lets the compiler
vectorize them. I/O lives only in `io_mod` and the driver. Orchestration (loops over
scenarios/timesteps) lives in `scenario_mod`, not in the kernels.

## Recommended Project Structure

```
fortran-fortress/
├── Makefile                 # build orchestration; encodes module compile order
├── README.md
├── src/
│   ├── kinds.f90            # kinds_mod        — precision (wp = real64)
│   ├── constants.f90        # constants_mod    — physical & model coefficients
│   ├── grid.f90             # grid_mod         — type(cell), type(grid_t), allocate
│   ├── heat_index.f90       # heat_index_mod   — elemental apparent-temp kernel
│   ├── uhi.f90              # uhi_mod          — elemental UHI-offset kernel
│   ├── diurnal.f90          # diurnal_mod      — elemental day–night modulation
│   ├── scenario.f90         # scenario_mod     — type(scenario_t), run/apply
│   ├── summary.f90          # summary_mod      — reductions for the report
│   ├── io.f90               # io_mod           — read config / write CSV / print
│   └── main.f90             # program uhi_sim  — composition root / driver
├── test/
│   ├── test_heat_index.f90  # asserts known heat-index reference values
│   ├── test_uhi.f90         # asserts dense-treeless > green-waterfront ordering
│   ├── test_diurnal.f90     # asserts night urban–rural gap > daytime gap
│   └── test_io.f90          # round-trips a small config through read→write
├── data/
│   ├── hcmc_districts.csv   # seed grid: per-district params (one row per cell)
│   └── scenarios.csv        # baseline + "add trees" / "more concrete" definitions
├── output/                  # .gitignored — generated results_*.csv land here
│   └── .gitkeep
└── build/                   # .gitignored — *.o and *.mod (compiler artifacts)
```

### Structure Rationale

- **`src/` flat, one module per file, filename = module concept:** Fortran has no
  package namespacing; the file/module mapping *is* the navigation aid. One module per
  file also keeps the Makefile dependency graph readable and lets `make` rebuild the
  minimal set when one module changes.
- **Source files ordered by dependency depth (kinds → … → main):** mirrors the build
  order so a reader scans `src/` top-to-bottom and sees foundations first.
- **`test/` holds standalone test driver programs**, one per module under test. Each is a
  tiny `program` that `use`s the target module and stops with a nonzero code on failure
  (see Testing pattern). No framework required for a project this size.
- **`data/` is input, `output/` is generated:** keeping them separate means `output/` can
  be wiped/git-ignored freely, and the "edit scenarios without recompiling" constraint is
  honored — config lives as data, not source.
- **`build/` is the single artifact sink** for both `*.o` and `*.mod` (via gfortran `-J`),
  so `make clean` is `rm -rf build` and the source tree stays clean.

## Architectural Patterns

### Pattern 1: Foundation-first module stack (acyclic `use` graph)

**What:** Arrange modules so each only `use`s modules strictly lower in the stack. No
cycles. The graph is linear/layered: `kinds → constants → grid → {physics} → scenario/summary → main`.
**When to use:** Always, in compiled Fortran — the compiler *requires* a `.mod` to exist
before a file that `use`s it compiles. An acyclic graph guarantees a valid topological
build order exists.
**Trade-offs:** Forces you to decide ownership up front (where does a constant live?).
Pays off as zero circular-dependency pain and a Makefile that "just works."

**Example:**
```fortran
module kinds_mod
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private
  integer, parameter, public :: wp = real64   ! working precision, one place
end module kinds_mod

module heat_index_mod
  use kinds_mod,     only: wp
  use constants_mod, only: hi_c1, hi_c2        ! only-lists keep deps explicit
  implicit none
  private
  public :: heat_index
contains
  elemental pure function heat_index(t_air, rh) result(hi)
    real(wp), intent(in) :: t_air, rh
    real(wp)             :: hi
    hi = t_air + hi_c1*rh + hi_c2*t_air*rh     ! illustrative; real formula later
  end function heat_index
end module heat_index_mod
```

### Pattern 2: Derived type for a cell + allocatable grid (Array-of-Structs)

**What:** Model one district as a `type(cell)` and the city as a 2D **allocatable** array
of cells, sized at runtime from the input file. Wrap it in a `grid_t` carrying dimensions
and metadata.
**When to use:** District-scale grids (tens–hundreds of cells) where clarity beats raw
throughput. AoS keeps "everything about a cell in one place," which matches how the data
file reads (one row = one cell).
**Trade-offs:** AoS is slightly less cache/SIMD-friendly than Struct-of-Arrays at large
N, but at district scale that is irrelevant. Crucially, you still get vectorization for
free because component references on a derived-type array yield plain arrays you feed to
elemental kernels (Pattern 3). If you ever scale to millions of cells, switch the hot
fields to SoA — but do not pay that complexity now.

**Example:**
```fortran
module grid_mod
  use kinds_mod, only: wp
  implicit none
  private
  public :: cell, grid_t, allocate_grid, deallocate_grid

  type :: cell
    character(len=:), allocatable :: name      ! e.g. "District 1"
    real(wp) :: t_air    = 0.0_wp              ! air temperature (degC)
    real(wp) :: rh       = 0.0_wp              ! relative humidity (%)
    real(wp) :: water_km = 0.0_wp              ! distance to river/ocean (km)
    real(wp) :: building = 0.0_wp              ! building density 0..1
    real(wp) :: tree     = 0.0_wp              ! tree density 0..1
    logical  :: is_urban = .true.
  end type cell

  type :: grid_t
    integer :: nx = 0, ny = 0
    type(cell), allocatable :: cells(:,:)      ! the city; allocate(cells(nx,ny))
  end type grid_t
contains
  subroutine allocate_grid(g, nx, ny)
    type(grid_t), intent(out) :: g
    integer,      intent(in)  :: nx, ny
    g%nx = nx; g%ny = ny
    allocate(g%cells(nx, ny))                  ! no manual free needed: see note
  end subroutine allocate_grid
end module grid_mod
```
> Modern Fortran auto-deallocates allocatables on scope exit; an explicit
> `deallocate_grid` is provided only for long-lived/reused grids, not leak avoidance.

### Pattern 3: `elemental pure` kernels that broadcast over the grid

**What:** Write each physics function as `elemental pure` over **scalars**. Apply it to the
whole grid in one call by passing component arrays — `g%cells%t_air` is a real array, and
an elemental function maps element-wise, returning a conformable array.
**When to use:** Every per-cell physics computation. It is the single most idiomatic
modern-Fortran "vectorize over the grid" move and keeps kernels scalar-simple to test.
**Trade-offs:** Elemental procedures may not contain I/O, `stop`, or pointer args — which
is exactly the discipline you want for physics. `pure` additionally enables `do concurrent`
and helps the optimizer.

**Example:**
```fortran
! Whole-grid evaluation with NO explicit loop — elemental broadcasts:
real(wp), allocatable :: hi(:,:), feels(:,:)
hi    = heat_index(g%cells%t_air, g%cells%rh)                 ! rank-2 in, rank-2 out
feels = hi + uhi_offset(g%cells%building, g%cells%tree, &
                        g%cells%water_km, g%cells%is_urban)   ! still elemental
feels = feels * diurnal_factor(hour, g%cells%is_urban)        ! scalar+array mix OK
```
For readability-over-cleverness or when you need a reduction, an explicit
`do concurrent (i=1:nx, j=1:ny)` loop calling the same `pure` functions is equally valid
and trivially parallelizable later.

### Pattern 4: Scenarios & timesteps as outer loops over pure kernels

**What:** Keep the kernels stateless; express "baseline vs add-trees vs more-concrete" and
"morning/peak/night" as **outer loops** in `scenario_mod`. Each scenario is a `type` that
describes a mutation (e.g. `tree_delta`, `building_delta`); apply it to a *copy* of the
grid, then sweep timesteps.
**When to use:** Always — it cleanly separates "what we vary" (orchestration) from "the
physics" (kernels), and produces one tidy results stream `(scenario, timestep, cell)`.
**Trade-offs:** Copying the grid per scenario costs memory, but district grids are tiny and
copy-then-mutate keeps the baseline pristine and scenarios independent (easy to reason
about and test).

**Example:**
```fortran
do s = 1, size(scenarios)
  work = baseline                         ! value copy; baseline untouched
  call apply_scenario(work, scenarios(s)) ! e.g. work%cells%tree += tree_delta
  do t = 1, size(hours)
    feels = evaluate_grid(work, hours(t)) ! pure kernels (Pattern 3)
    call write_results_csv(unit, scenarios(s), hours(t), work, feels)
  end do
end do
```

### Pattern 5: Status-flag error handling, not `stop` in libraries

**What:** I/O and parsing routines return an `integer :: stat` / `character :: msg` instead
of calling `stop`. Only the **driver** decides to abort (with a clear message and exit
code). Propagate `iostat=`/`iomsg=` from `open/read/write` upward.
**When to use:** All of `io_mod`. Makes I/O testable (a test can assert a bad file yields a
nonzero stat) and keeps fatal-exit policy in one place.
**Trade-offs:** A little boilerplate per call vs. robust, testable, single-exit-point I/O.

## Data Flow

### Pipeline Flow (input → results)

```
data/hcmc_districts.csv          data/scenarios.csv
        │                                │
        ▼  io_mod%read_grid_config       ▼  io_mod%read_scenarios
   type(grid_t) baseline           scenario_t array
        │                                │
        └──────────────┬─────────────────┘
                       ▼  scenario_mod%run_all
        for each scenario:  work = copy(baseline); apply_scenario(work)
          for each timestep (hour):
                       ▼  DOMAIN kernels (pure/elemental, no I/O)
            heat_index(t_air, rh)
               → uhi_offset(building, tree, water_km, is_urban)
               → diurnal_factor(hour, is_urban)
                       ▼
            feels(:,:)  for this (scenario, hour)
                       │
        ┌──────────────┴──────────────────┐
        ▼  io_mod%write_results_csv         ▼  summary_mod (reductions)
  output/results.csv                  hottest/coolest, city avg,
  (row per cell per timestep/scenario) urban–rural gap
                                            ▼  io_mod%print_summary → terminal
```

### Key Data Flows

1. **Config → grid:** `io_mod` parses each CSV row into a `cell`, fills `grid_t%cells(i,j)`.
   Grid dimensions come from the file (row/col count), so the grid is **allocated at
   runtime** — never hard-coded sizes.
2. **Grid → feels-like field:** physics kernels consume component arrays and produce a
   `feels(:,:)` array per `(scenario, timestep)`. Pure data-in/data-out; the grid itself is
   read-only here (the working copy was already mutated by `apply_scenario`).
3. **Results → CSV + summary:** the same `feels` field fans out to (a) an append to the CSV
   stream and (b) reductions in `summary_mod`. The driver prints the summary last.

### State Management

There is essentially **no global mutable state** — and that is the point. The only "state"
is the `grid_t`/`scenario_t` values threaded explicitly through call arguments. Constants
live in `constants_mod` as `parameter`s (immutable). Avoid module-level mutable variables;
pass everything as `intent(in)/intent(out)/intent(inout)` arguments so the program stays
referentially transparent and testable.

## Build Order (gfortran `.mod` dependencies)

**This is the load-bearing constraint for Fortran.** When gfortran compiles a file
containing `module foo`, it emits `foo.mod`. Any file that does `use foo` will not compile
until `foo.mod` already exists on disk. Therefore **a module must be compiled before any
module that uses it**, and `make` must encode that order via object dependencies.

**Topological compile order (must be respected):**

```
1. kinds.f90        (no deps)
2. constants.f90    (use kinds_mod)
3. grid.f90         (use kinds_mod)
4. heat_index.f90   (use kinds_mod, constants_mod)
5. uhi.f90          (use kinds_mod, constants_mod)
6. diurnal.f90      (use kinds_mod, constants_mod)
7. summary.f90      (use kinds_mod, grid_mod)
8. scenario.f90     (use kinds_mod, grid_mod, heat_index_mod, uhi_mod, diurnal_mod)
9. io.f90           (use kinds_mod, grid_mod, scenario_mod)
10. main.f90        (use everything it orchestrates)
```

**Makefile implications (the project's existing Makefile already does this correctly):**

- Use `gfortran -J build` so all `.mod` and `.o` land in `build/`, and `-Ibuild` so
  compiles find existing `.mod` files.
- Encode the order as **object-to-object prerequisites**, not just source rules:
  ```make
  build/constants.o: build/kinds.o
  build/grid.o:      build/kinds.o
  build/heat_index.o: build/kinds.o build/constants.o
  build/scenario.o:  build/grid.o build/heat_index.o build/uhi.o build/diurnal.o
  build/io.o:        build/grid.o build/scenario.o
  build/main.o:      build/io.o build/scenario.o build/summary.o
  ```
  These prerequisites force `make` to (re)compile a dependency's `.mod` before its users —
  the existing scaffold already demonstrates the pattern with `build/main.o: build/numerics.o`.
- **Recompilation cascade:** because `.mod` files are interfaces, editing a low module
  (e.g. `kinds.f90`) invalidates everything above it. The explicit prerequisites make
  `make` rebuild exactly that cascade and no more. (Optionally auto-generate deps with a
  tool like `makedepf90` or `fpm`, but a hand-written 10-line dep block is clearest here.)
- **Test build order:** each `test/test_*.f90` depends on the `.o`/`.mod` of the module it
  tests plus the foundation modules — same rule, smaller graph.

> If the project ever outgrows the hand-written Makefile, **fpm (Fortran Package Manager)**
> computes module build order automatically from `use` statements. It is the modern default
> for new Fortran projects, but make is perfectly adequate (and already working) at this size.

## Idiomatic Modern-Fortran Patterns (checklist)

| Idiom | Use it for | Why |
|-------|-----------|-----|
| `implicit none` in every module/program | Always | Catches typos as compile errors; non-negotiable |
| `wp = real64` from `iso_fortran_env`, all literals `0.0_wp` | All reals | One precision knob; avoids accidental single-precision physics |
| Derived types (`type :: cell`) | Cell & scenario records | Groups related fields; self-documenting |
| Allocatable arrays sized at runtime | The grid, results | No fixed dimensions; auto-deallocated on scope exit (no leaks) |
| `elemental pure function` | All physics kernels | Broadcasts over grid arrays; enables `do concurrent`; testable |
| `pure` (where not elemental) | Reductions/helpers | Optimizer hints; safe in concurrent loops |
| `module` + `private` + explicit `public` | Every module | Encapsulation; controlled API surface |
| `use mod, only: name` | Every `use` | Documents exact dependency; avoids name clashes |
| `intent(in/out/inout)` on every dummy arg | All procedures | Compiler-checked contracts; readability |
| `do concurrent` | Grid sweeps needing a loop | Parallel-ready; signals no iteration dependence |
| `iostat=`/`iomsg=` + status return | All I/O | Robust, testable error handling without `stop` in libs |
| Contained procedures (`contains`) in modules | Group related routines | Module-private helpers without polluting global names |

## Anti-Patterns

### Anti-Pattern 1: Doing I/O or holding state inside physics kernels

**What people do:** `print *` debug lines, file reads, or module-level mutable accumulators
inside `heat_index`/`uhi_offset`.
**Why it's wrong:** Breaks `elemental`/`pure` (won't even compile elemental), prevents
vectorization, and makes the kernel impossible to unit-test in isolation.
**Do this instead:** Keep kernels pure data-in/data-out; confine all I/O to `io_mod` and
the driver.

### Anti-Pattern 2: Hard-coded grid dimensions / district values in source

**What people do:** `real :: grid(20,20)` and `data` statements with district numbers.
**Why it's wrong:** Violates the "edit scenarios without recompiling" constraint and the
"load from a data file" requirement; every tweak forces a rebuild.
**Do this instead:** Read dimensions and values from `data/*.csv` into **allocatable**
arrays at runtime.

### Anti-Pattern 3: Legacy Fortran habits (implicit typing, fixed-form, COMMON, single precision)

**What people do:** Omit `implicit none`, use `.f` fixed-form, `common` blocks for shared
state, default `real` literals like `0.5`.
**Why it's wrong:** Implicit typing hides bugs; COMMON is unscoped global state; default
`real` is single-precision and will visibly degrade a temperature model.
**Do this instead:** `implicit none` everywhere, free-form `.f90`, pass state as arguments
or `type`s, and tag every literal with `_wp`.

### Anti-Pattern 4: Circular `use` dependencies

**What people do:** Let `io_mod` use `scenario_mod` while `scenario_mod` uses `io_mod`.
**Why it's wrong:** No valid `.mod` build order exists; gfortran cannot compile it.
**Do this instead:** Keep the `use` graph strictly layered (Pattern 1). I/O depends on
domain types, never the reverse.

### Anti-Pattern 5: Reinventing matrix/array loops

**What people do:** Triple-nested explicit loops with scalar temporaries for things Fortran
does natively.
**Why it's wrong:** More code, more bugs, often slower than whole-array/elemental
expressions the compiler optimizes.
**Do this instead:** Use array syntax, `elemental` kernels, and intrinsics (`sum`, `maxval`,
`maxloc`, `count`, `pack`) — e.g. the urban–rural gap is
`sum(feels, mask=urban)/count(urban) - sum(feels, mask=.not.urban)/count(.not.urban)`.

## Testing Strategy (supports testability quality goal)

No framework is needed at this scale. Each `test/test_*.f90` is a standalone `program` that
`use`s one module, computes against known references, and `error stop`s with a message on
failure (nonzero exit code → `make test` fails). Because kernels are `pure`/`elemental` and
take plain numbers, tests are trivial:

```fortran
program test_uhi
  use kinds_mod, only: wp
  use uhi_mod,   only: uhi_offset
  implicit none
  real(wp) :: dense, green
  dense = uhi_offset(building=0.9_wp, tree=0.1_wp, water_km=8.0_wp, is_urban=.true.)
  green = uhi_offset(building=0.1_wp, tree=0.9_wp, water_km=0.5_wp, is_urban=.false.)
  if (.not. (dense > green)) error stop "UHI: dense/treeless must be hotter than green"
  print *, "test_uhi OK"
end program test_uhi
```

Map tests to the project's core value: assert (1) heat-index reference values, (2)
dense-treeless > green-waterfront ordering, (3) night urban–rural gap > daytime gap, and
(4) a config read→write round-trip. A `make test` target builds and runs each. If the suite
later grows, **test-drive** or **pFUnit** are the standard Fortran unit-test frameworks —
but they are overkill for v1.

## Integration Points

### External Interfaces

| Interface | Pattern | Notes |
|-----------|---------|-------|
| `data/*.csv` (input) | List-directed or explicit `read` with `iostat` | Parse header row; one record → one `cell`; derive grid size from row/col counts |
| `output/results.csv` | Formatted `write` to a unit | Stream rows `(scenario, hour, i, j, name, feels, …)`; write header once |
| Terminal summary | `write(*,*)` / formatted | Hottest/coolest, city average, urban–rural gap — last thing the driver does |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| driver ↔ scenario_mod | Direct call, pass `grid_t` + `scenario_t` array | Driver owns lifetime & exit policy |
| scenario_mod ↔ physics | Direct call to `elemental pure` funcs | One-way; physics never calls back up |
| io_mod ↔ grid_mod | io fills/reads `type(cell)` | io depends on types; types never depend on io |
| any module ↔ kinds/constants | `use … only:` | Foundation; used by all, uses nothing |

## Sources

- Fortran 2008/2018 standard language semantics: `elemental`/`pure` procedures, allocatable
  arrays, derived types, `do concurrent`, `iso_fortran_env` (`real64`). [Curated language
  knowledge — HIGH confidence; stable, non-volatile facts.]
- gfortran module system: `.mod` generation and the requirement that a module compile before
  its users; `-J`/`-I` module path flags. [Curated — HIGH confidence.]
- Established modern-Fortran style guidance (Fortran-lang / community best practices): one
  module per file, `implicit none`, explicit `only` imports, status-flag error handling, fpm
  for automatic build ordering. [Curated — HIGH confidence.]
- Existing project scaffold (`Makefile`, `src/numerics.f90`) — already demonstrates `-J build`
  and explicit object-order prerequisites; this research generalizes that pattern.

---
*Architecture research for: modern Fortran 2D grid simulation (HCMC urban-heat-island)*
*Researched: 2026-06-28*
