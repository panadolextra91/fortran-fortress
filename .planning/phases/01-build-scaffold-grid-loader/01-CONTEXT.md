# Phase 1: Build Scaffold & Grid Loader - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Stand up the fpm project and the foundation/data layers of the simulator: a runnable
`fpm` project (retiring the throwaway Hello-World Makefile scaffold) whose driver **loads a
2D grid of Ho Chi Minh City cells from an editable data file, validates it, and prints the
loaded cells**. Model coefficients (UHI weights, diurnal multipliers) are also loaded from
config at runtime. Covers requirements GRID-01, GRID-02, GRID-03, GRID-04.

This phase does NOT compute feels-like temperature, UHI offset, the diurnal cycle,
scenarios, or CSV output — those are Phases 2–4. Phase 1 ends when the grid round-trips
from file to terminal.

</domain>

<decisions>
## Implementation Decisions

### Data File Format
- **D-01:** Two-tier format. The **grid/district table is CSV** (one row per district,
  human-editable in Excel/any text editor). The **model coefficients** (UHI weights
  `w_build`/`w_urban`/`w_tree`/`w_water`, diurnal multipliers, baseline weather) live in a
  **Fortran `namelist`** file — Fortran-native, no parser code, edit-without-recompile.
- **D-02:** Both files are plain-text, version-controlled, and live under a `data/`
  directory. Editing either changes program output with no recompile (satisfies GRID-01,
  GRID-04).

### Grid Geometry
- **D-03:** The grid is a **list of districts, each carrying explicit `(i, j)` grid
  coordinates** that place it on a 2D raster approximating the HCMC map. This is a real 2D
  heat map (cells have spatial position) while staying relatable (each cell is a named
  district), NOT a dense interpolated raster and NOT a coordinate-less 1D ranking.
- **D-04:** Empty grid cells (raster positions with no district) are expected and fine for
  Phase 1 — the loader just holds the sparse district list with coordinates. How to *render*
  empty cells is deferred to Phase 4 (output). The grid extent (max i, max j) is derived
  from the data (or set in the namelist).

### Seed Data Scope
- **D-05:** Ship **~12–16 real HCMC districts** (not just the 5 research archetypes), chosen
  to cover all five archetypes AND be recognizable: e.g. District 1 (dense core), an
  industrial zone (e.g. parts of Thu Duc / Binh Tan — hottest), a park/green cell (e.g. Tao
  Dan area), Can Gio (mangrove/coast — coolest control), a peri-urban/rural fringe, plus
  familiar districts (3, 5, 7, 10, Binh Thanh, Tan Binh, Go Vap, ...). Richer map, more
  data entry — acceptable.
- **D-06:** Per-cell fields (GRID-02): air temperature, relative humidity, distance to
  river/ocean, building density, tree density, urban/rural class — plus district name and
  `(i, j)`. All numeric fields stored/converted to `real(real64)` to avoid integer-division
  / precision loss downstream.

### Error / Validation Behavior
- **D-07:** **Fail loud, fail early.** A malformed or out-of-range row (bad column count,
  unparseable number, RH outside 0–100, density outside 0–1, etc.) stops the program with a
  clear message naming the **line number and the reason**. No silent skipping, no silent
  clamping — this prevents column-shift bugs from masquerading as science errors (PITFALLS
  A9/A10). Validation runs at load time, before any physics.

### Build / Toolchain
- **D-08:** Build with **fpm** (already a locked project decision). Phase 1 creates
  `fpm.toml` and the `src/`/`test/`/`data/` layout, and **retires the Hello-World Makefile
  scaffold** (`Makefile`, `src/numerics.f90`, `src/main.f90`). `fpm build`/`fpm run`/`fpm
  test` must run clean. Note: **fpm is not yet installed** — install via `brew install fpm`
  at the start of execution.
- **D-09:** Use a single real kind module (`kinds_mod`, `wp = real64`) and `implicit none`
  everywhere; enable a strict dev flag profile (`-fcheck=all -Wall -Wextra -fimplicit-none
  -finit-real=snan`) vs a `-O2` release profile (per STACK.md).

### Claude's Discretion
- Exact CSV column order/header names, the precise `(i,j)` coordinates assigned to each
  district, the namelist group/variable names, and the internal derived-type field names are
  left to research/planning — as long as the decisions above hold.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 1: Build Scaffold & Grid Loader" — goal, success criteria, plan breakdown (01-01..01-04).
- `.planning/REQUIREMENTS.md` — GRID-01, GRID-02, GRID-03, GRID-04 (the four requirements this phase delivers).
- `.planning/PROJECT.md` — Core Value, Constraints (fpm + real64), Key Decisions table.

### Toolchain & I/O (most relevant for this phase)
- `.planning/research/STACK.md` — fpm vs Makefile rationale, fpm.toml layout, namelist + delimited-read for input, formatted-write for output, dev/release gfortran flag profiles, test-drive vs hand-rolled assert.
- `.planning/research/ARCHITECTURE.md` — module decomposition (`kinds_mod` → `constants_mod` → `grid_mod` → `io_mod` …), derived `type(cell)` / `grid_t`, allocatable grid, build/compile order, src/test/data/output directory layout.
- `.planning/research/PITFALLS.md` — §A (Fortran/tooling): stale `.mod`, mixed real kinds / missing `_dp`, integer division, uninitialized locals; §A9/A10 (CSV/IO): fixed-width `*****` overflow, decimal-locale, loud row validation to avoid column-shift.

### Data values (seed file content)
- `.planning/research/FEATURES.md` §"HCMC Baselines" + "district archetypes" — realistic temperature/humidity ranges and the District 1 / industrial / park / Can Gio / rural-fringe archetype parameters to seed the ~12–16 districts.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/numerics.f90` (current scaffold): demonstrates the idiomatic `dp = real64` kind
  pattern, `PI` parameter, and `pure` functions in a module. The **kind/module idiom is
  reusable** as the basis for `kinds_mod`/`constants_mod`, even though the file itself is
  retired.
- `.vscode/extensions.json`: already recommends the Modern Fortran extension — keep.

### Established Patterns
- The retired `Makefile` encodes the correct manual module compile order (`-J build`,
  explicit object prerequisites). fpm replaces this by auto-resolving order, but the pattern
  documents the dependency intent if a Makefile fallback is ever needed.

### Integration Points
- This phase produces the `grid_t` data structure and the loaded coefficients that **Phase 2
  (physics kernels) consumes directly**. Design the derived types and the loader API with
  that downstream consumer in mind (pure-function-friendly, no global state).

</code_context>

<specifics>
## Specific Ideas

- The data file should be **editable in Excel** for the grid (hence CSV) — the user wants to
  tweak districts/values and re-run without recompiling.
- The seed map should "feel like Ho Chi Minh City" — use real, recognizable district names,
  not abstract cell IDs.
- Loud, line-numbered load errors are a deliberate teaching/debugging aid, not just defensive
  code.

</specifics>

<deferred>
## Deferred Ideas

- **Rendering of empty grid cells** (raster positions with no district) — belongs to Phase 4
  (CSV Export & Console Summary), not Phase 1.
- **Humidex toggle, continuous distance-to-water decay, smooth cosine diurnal curve, more
  districts/finer archetypes, seasonal runs** — all tracked as v2 (`REFN-01..05` in
  REQUIREMENTS.md).
- **Tuning UHI weights so the night gap lands in ~3–8 °C** — a Phase 2/3 calibration concern
  (already in STATE.md blockers); Phase 1 only needs the weights to *load*, not to be tuned.

</deferred>

---

*Phase: 1-Build Scaffold & Grid Loader*
*Context gathered: 2026-06-28*
