# Stack Research

**Domain:** Modern Fortran scientific-computing program (2D urban-heat-island grid simulator, CSV output) on macOS / Apple Silicon
**Researched:** 2026-06-28
**Confidence:** HIGH

## Executive Recommendation (TL;DR)

- **Compiler:** `gfortran` from Homebrew GCC 16.1.0 (already installed). Standard `-std=f2018`, `implicit none` everywhere, `real64` kinds. **[HIGH]**
- **Build system:** **`fpm` (Fortran Package Manager) v0.13.0** is the recommended modern choice. It auto-resolves Fortran module compile-order — the single biggest source of hand-written-Makefile pain — and gives you `fpm test`/`fpm run` for free. A **plain GNU Makefile** is an acceptable fallback that honors the existing project constraint, *provided* module dependency order is handled correctly. **Avoid CMake** — overkill at this size. **[HIGH]**
- **Input data:** **Fortran `namelist`** for scenario/config knobs (UHI coefficients, times of day, scenario toggles) + a **simple whitespace/comma-delimited text table** read with list-directed input for the per-district grid seed data. No parsing library needed. **[HIGH]**
- **CSV output:** Plain **formatted `write` statements**. No library required or warranted. **[HIGH]**
- **External libraries:** **None required.** Standard Fortran 2018 intrinsics (`maxloc`/`minloc`/`sum`/`maxval`) cover everything this project needs. `fortran-stdlib` is *optional* and not worth the build complexity for v1. **[HIGH]**
- **Testing:** **`test-drive` v0.6.0** if you adopt fpm (zero-friction, `fpm test`); otherwise a **hand-written `assert` module** (~30 lines) is perfectly adequate for a learning project. **Avoid `veggies`** (heavier, more ceremony). **[HIGH]**

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| gfortran (GCC) | 16.1.0 (Homebrew) | Fortran compiler | Already installed/verified; the de-facto free Fortran compiler. Excellent F2018 coverage, strong runtime checks (`-fcheck=all`), great diagnostics for learners. |
| Fortran standard | F2018 (`-std=f2018`) | Language level | F2018 is fully supported by GCC 16 and adds nothing risky over F2008. Gives `implicit none external`, better `error stop`, etc. F2023 features are still uneven across compilers — no need here. |
| fpm | 0.13.0 (Feb 2026) | Build + test + run driver | Auto-derives module dependency graph (no manual ordering), one-command build/test/run, trivial dependency fetching if ever needed. Standard modern Fortran workflow. |
| iso_fortran_env | intrinsic | Portable kinds | Use `real64`/`int32` from this intrinsic module instead of magic `kind=8`. Portable, self-documenting, matches the project's `real64` constraint. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| test-drive | 0.6.0 | Unit testing | Only if using fpm. Add under `[dev-dependencies]`; run with `fpm test`. Standard-Fortran-only, no extra system deps. |
| fortran-stdlib | 0.8.1 (Jan 2026) | sorting, strings, IO helpers | **Optional / skip for v1.** Only pull in if you later want `stdlib_sorting`, `stdlib_string_type`, or `stdlib_io` conveniences. Not needed for the planned feature set. |

> The honest call: **for this project the standard language is sufficient.** Don't add stdlib just to have it — it lengthens build/CI and adds a dependency for functionality (`minloc`, `maxloc`, `sum`, formatted IO) the compiler already provides.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| GNU make | Fallback build driver | Already present in the scaffold; fine if you stay off fpm. Watch module compile order. |
| VS Code + Modern Fortran extension | Editor / LSP | Already configured (`.vscode/extensions.json`). Uses `fortls` language server for hovers, diagnostics, go-to-definition. |
| fortls (Fortran Language Server) | IDE intelligence | Install via `pipx install fortls`. Reads `fpm.toml` or a `.fortls` config to find module dirs. |
| gnuplot / Python+matplotlib / Excel | External plotting of CSV | Out of the Fortran build; just consumers of the CSV output. |

### Recommended gfortran flags

**Development / debug profile (use this while building the model — correctness first):**

```
-g -O0 -std=f2018 -fimplicit-none
-Wall -Wextra -Wpedantic
-fcheck=all -fbacktrace
-ffpe-trap=invalid,zero,overflow
-finit-real=snan
```

- `-fcheck=all` catches array-bounds and shape errors at runtime — invaluable for a grid program.
- `-ffpe-trap=invalid,zero,overflow` makes NaN/Inf from a bad heat-index/humidity formula crash *at the source* instead of silently propagating into the CSV.
- `-finit-real=snan` surfaces use-of-uninitialized-variable bugs immediately.
- `-Wall -Wextra` flags unused/uninitialized variables and implicit conversions — great teaching feedback.

**Release / run profile (for the final runs):**

```
-O2 -std=f2018 -fimplicit-none -Wall
```

- `-O2` is the workhorse and plenty for a district-scale grid (tens to low-hundreds of cells). `-O3` buys essentially nothing here and can complicate floating-point reproducibility.
- On Apple Silicon, **prefer plain `-O2`** (optionally `-mcpu=native`). **Do not reflexively copy `-march=native`** — that is an x86 idiom; on aarch64 GCC the correct knob is `-mcpu=`/`-mtune=`, and tuning is irrelevant for a grid this small.

**OpenMP:** add `-fopenmp` *only if* you actually parallelize. For a district-scale grid the work is trivial and parallelization is unwarranted — see "What NOT to Use."

### Data I/O — prescriptive choices

**Input — two-tier approach:**

1. **Config / scenario parameters → Fortran `namelist`.** UHI coefficients, list of times-of-day, scenario definitions ("add trees", "more concrete"), output paths. Namelist is built into the language: declare a `namelist /uhi/ ...` group and `read(unit, nml=uhi)`. Zero parsing code, human-editable `&uhi ... /` files, lets scenarios change without recompiling (directly satisfies the project's "edit without recompiling" constraint).

2. **Per-district seed grid → simple delimited text table.** A small file with one row per district (name, temp, humidity, distance-to-water, building density, tree density, urban/rural flag). Read it with **list-directed input** (`read(unit,*) ...`) over comma/space-separated fields, skipping `#` comment lines and a header. This is a dozen lines of robust code.

**Output — CSV via formatted `write`:**

```fortran
! header
write(out,'(A)') 'district,time,scenario,t_air,rh,heat_index,feels_like'
! one row per cell/timestep/scenario
write(out,'(A,",",A,",",A,4(",",F0.2))') &
     trim(name), trim(time_label), trim(scenario), t_air, rh, hi, feels
```

Clean, dependency-free, and `F0.2` avoids fixed-width column headaches. No CSV library is needed or recommended.

### Testing approach

**If using fpm → `test-drive`.** Add to `fpm.toml`:

```toml
[dev-dependencies]
test-drive.git = "https://github.com/fortran-lang/test-drive"
```

Write test suites returning `unittest_type` arrays via `new_unittest`; run everything with `fpm test`. Standard-Fortran-only, integrates with fpm/CMake/meson, and is the community default.

**If staying on a Makefile → a tiny hand-rolled `assert` module** (a `check(cond, msg)` subroutine that prints PASS/FAIL and `error stop`s on failure) is entirely sufficient for a learning project and keeps the dependency count at zero. Focus tests on the **science invariants**, which are the real risk: dense/treeless urban cell > green/waterfront cell at the same baseline, and the urban–rural gap widening at night.

## Installation

```bash
# Compiler (already installed — verify)
gfortran --version          # expect GCC 16.1.0

# Recommended: Fortran Package Manager
brew install fpm            # or: download the release binary from github.com/fortran-lang/fpm

# Optional editor intelligence
pipx install fortls

# Optional (NOT needed for v1): fortran-stdlib is fetched automatically by fpm
# if/when you add it under [dependencies] in fpm.toml — no manual install.
```

`fpm` project bootstrap:

```bash
fpm new heat_island        # scaffolds src/, app/, test/, fpm.toml
fpm build
fpm run
fpm test
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| fpm | Plain GNU Makefile | You want zero new tools and will hand-manage module compile order (the existing scaffold already does this). Fine at this size; just fragile as the module count grows. |
| fpm | CMake | Only if you must integrate with a large external C/Fortran build, ship installable targets, or link heavyweight libs (HDF5/NetCDF/MPI). None apply here. |
| namelist (config) | TOML/JSON via a parser lib | Only if non-Fortran tools must also read the config. Adds a dependency for no benefit in a self-contained model. |
| list-directed read (grid) | Hand-written CSV parser | Only if input fields contain quoted commas/escaping. District seed data won't — keep it simple. |
| test-drive | Hand-written assert module | Makefile-only projects, or when you want literally zero dependencies. Great for a learner. |
| Standard library only | fortran-stdlib | You later need real sorting of many records, rich string handling, or stats utilities. Not for v1. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| CMake for this project | Heavy boilerplate, slow iteration, solves problems (large multi-lang builds, install targets) this project doesn't have | fpm, or a small Makefile |
| `-march=native` on Apple Silicon | x86 idiom; wrong knob on aarch64 GCC and can produce confusing warnings/errors. Tuning is pointless for a tiny grid | `-O2` (optionally `-mcpu=native`) |
| OpenMP / `-fopenmp` in v1 | District-scale grid is microseconds of work; parallelism adds race-condition risk and nondeterministic output for zero speedup | Plain serial loops; revisit only if grid resolution explodes |
| `fortran-stdlib` "just in case" | Adds a build dependency and CI time for functions (`minloc`/`maxloc`/`sum`/formatted IO) already intrinsic | Standard language intrinsics |
| A third-party CSV library | CSV *writing* is one `write` statement; a lib is pure overhead and another dependency to learn | Formatted `write` |
| veggies (test framework) | More setup ceremony and heavier than needed for a small illustrative project | test-drive, or a hand-rolled assert module |
| Fixed-format (`.f`/`.for`), `implicit` typing, `common` blocks, `goto`, `kind=8` magic numbers | Legacy Fortran 77 idioms; error-prone and against the project's "modern Fortran" constraint | Free-form `.f90`, `implicit none`, modules, `real64` from `iso_fortran_env` |
| `-O3 -ffast-math` for the science runs | `-ffast-math` breaks IEEE semantics and can mask/produce NaNs, undermining a model whose value is *believable numbers* | `-O2`; keep FP predictable |

## Stack Patterns by Variant

**If you want the smoothest modern workflow (recommended):**
- Use **fpm** + **test-drive**, layout `src/`, `app/main.f90`, `test/`.
- Because module ordering, test running, and (future) dependencies are all handled for you.

**If you must honor the existing "gfortran via make" constraint literally:**
- Keep the **Makefile**, define an explicit object/module dependency order (or generate it with `makedepf90`), and use a **hand-written assert module** for tests.
- Because it works and adds no tools — accept the manual dependency-ordering maintenance cost.

**If the grid later grows to thousands of cells or gains a time-stepped PDE:**
- Reconsider **OpenMP** (`-fopenmp`) and possibly **fortran-stdlib** sorting/stats.
- Because only then does parallelism/library tooling pay for itself.

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| gfortran | GCC 16.1.0 | Full F2018 support; `-std=f2018` safe. F2023 features still uneven — avoid relying on them. |
| fpm | 0.13.0 | Fixed GCC 15+ compatibility; works cleanly with GCC 16. Use `setup-fpm@v7+` if you add GitHub Actions CI. |
| fortran-stdlib | 0.8.1 | Builds with fpm or CMake; pre-1.0 so APIs can shift between minor versions — pin a tag if adopted. |
| test-drive | 0.6.0 | Pure standard Fortran; compiles with GCC 16 without flags fuss. |

## Sources

- github.com/fortran-lang/fpm/releases — fpm v0.13.0 (released 2026-02-17), GCC 15+ compatibility fixes — verified [HIGH]
- github.com/fortran-lang/stdlib/releases — fortran-stdlib v0.8.1 (released 2026-01-26) — verified [HIGH]
- github.com/fortran-lang/test-drive — test-drive v0.6.0, standard-Fortran-only testing framework — verified [HIGH]
- GCC/gfortran documentation — flag semantics (`-fcheck`, `-ffpe-trap`, `-finit-real`, `-std`, aarch64 `-mcpu` vs x86 `-march`) — training knowledge, HIGH confidence
- .planning/PROJECT.md — project constraints (gfortran via make, macOS Apple Silicon, real64, CSV output)

---
*Stack research for: modern Fortran scientific-computing UHI grid simulator*
*Researched: 2026-06-28*
