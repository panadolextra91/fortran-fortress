# Pitfalls Research

**Domain:** Modern Fortran scientific computing + Urban Heat Island (UHI) / heat-index modeling for Ho Chi Minh City
**Researched:** 2026-06-28
**Confidence:** HIGH (Fortran tooling — well-established; UHI/heat-index science — verified against NOAA WPC and AMS/Nature sources)

This file has two buckets, as requested:
- **A. Fortran / Tooling pitfalls** — language and build-system traps that produce wrong numbers, silent precision loss, or broken builds.
- **B. Scientific / Modeling pitfalls** — domain errors that make the heat map *look* fine but be scientifically wrong (the project's core value is that the spatial/nocturnal pattern is believable, so these are the highest-stakes failures).

Phase names below are **suggested** (the roadmap is not yet written). The mapping table at the end ties each pitfall to a likely phase.

Suggested phase shorthand used throughout:
- **P1 — Scaffold/Build** (Makefile, module layout, compiler flags, `implicit none`, kinds module)
- **P2 — Grid + Data Loading** (2D grid type, read HCMC district data from file)
- **P3 — Heat Index** (apparent-temperature formula per cell)
- **P4 — UHI Adjustment** (building/tree/water offsets)
- **P5 — Day–Night Cycle** (diurnal evaluation, nocturnal gap)
- **P6 — Scenarios** (what-if comparison)
- **P7 — CSV Output + Summary**

---

## A. Critical Pitfalls — Fortran / Tooling

### A1: Silent precision loss from default-real literals (forgetting `_dp`)

**What goes wrong:**
Constants written as `0.5`, `1.2`, `26.7`, or `9.0/5.0` are **default (single) precision** even when assigned to a `real64` variable. The arithmetic is done in 32-bit first, then widened — so a `real(dp)` result silently carries only ~7 significant digits. The Rothfusz heat-index regression has large opposing terms (e.g. `-42.379 + 2.049*T + 10.143*RH - ...`) where catastrophic cancellation makes single-precision rounding visible in the output (feels-like temps off by a few tenths of a degree, non-reproducible across optimization levels).

**Why it happens:**
Fortran literals default to single precision; the kind is *not* inferred from the assignment target. `1.0/3.0` is a single-precision divide regardless of where it lands. Easy to forget on every literal in a long formula.

**How to avoid:**
- Define one kinds module early (P1): `integer, parameter :: dp = selected_real_kind(15, 307)` (or `use iso_fortran_env, only: dp => real64`).
- Suffix **every** real literal: `0.5_dp`, `26.7_dp`, `9.0_dp/5.0_dp`. No bare `0.5` in numeric code.
- Compile with `-Wall` (gfortran warns on some conversions) and add `-fdefault-real-8` **only as a diagnostic experiment**, never as the fix — if results change when you flip it, you have unsuffixed literals to clean up.

**Warning signs:**
Results shift when you change `-O0` → `-O2`; feels-like values that should be deterministic differ in the 2nd–3rd decimal between runs/machines; `-fdefault-real-8` changes the output.

**Phase to address:** P1 (kinds module + convention), enforced in P3/P4 (the formula-heavy phases).

---

### A2: Mixed-kind arithmetic and integer division in the formulas

**What goes wrong:**
Two related errors: (1) mixing a `real(dp)` with a default real produces a default-real intermediate (see A1); (2) **integer division** — `building_density / 100` where both are integers yields `0` for any density < 100, silently zeroing a UHI term. A grid loaded with integer-coded densities feeding a real offset is the classic trap.

**Why it happens:**
Fortran does no implicit float promotion in integer/integer division; `5/2 == 2`. If grid attributes are read as integers (counts, percentages) and used directly in a real offset, the offset collapses.

**How to avoid:**
- Store all physical model attributes as `real(dp)` in the grid type, even if the source data file holds whole numbers — convert at load time in P2.
- Where an integer must enter a real expression, wrap it: `real(building_count, dp)`.
- Unit-test one cell by hand: compute the expected offset on paper and `assert` the code matches.

**Warning signs:**
A UHI offset that is exactly `0.0` for many cells; scenario "more concrete" produces no change; offsets that jump in integer steps.

**Phase to address:** P2 (load as real) and P4 (offset math).

---

### A3: Module compile-order errors and stale `.mod` files

**What goes wrong:**
gfortran needs a module's `.mod` file to exist *before* compiling anything that `use`s it. A naive Makefile that compiles `*.f90` in alphabetical/glob order fails with `Fatal Error: Cannot open module file 'grid_mod.mod'`. Worse: after you edit a module's interface, a **stale `.mod`** left in the tree lets dependent files compile against the old interface, producing wrong behavior or link errors that "make clean" fixes — masking a real dependency bug.

**Why it happens:**
`.mod` files are compiler-generated build artifacts with no automatic dependency tracking in a hand-written Makefile. Order matters and is invisible to `make` unless you declare it.

**How to avoid:**
- In the Makefile, declare **explicit object dependencies** that mirror `use` statements: `main.o: grid_mod.o heatindex_mod.o`. Order the link/compile by dependency, not by glob.
- Add a real `clean` target that removes `*.o` **and** `*.mod`.
- Keep one module per file, file name == module name, so dependencies are obvious.
- Consider auto-dependency generation (e.g. `makedepf90`) or migrating to CMake/`fpm` if the module graph grows; for a handful of modules, explicit deps are fine.
- Build clean in CI/local once before trusting incremental builds.

**Warning signs:**
"Cannot open module file" errors; builds that only succeed after `make clean`; behavior that changes after a clean rebuild with no source change.

**Phase to address:** P1 (Makefile + module layout). Revisit whenever a new module is added.

---

### A4: Missing `implicit none` → implicit typing reintroduces bugs

**What goes wrong:**
Without `implicit none`, a typo'd variable (`tempurature`) is silently auto-declared (real if it starts a–h/o–z, integer if i–n). The misspelled variable holds garbage/zero, and the real one never gets updated — a logic bug with no compiler error. The `i`–`n` integer default also silently truncates a real loop accumulator.

**Why it happens:**
Legacy Fortran default. `implicit none` must be stated in **every** program/module/procedure scope; it is easy to add it to the module but forget it in a contained subroutine.

**How to avoid:**
- `implicit none` at the top of every `program`, `module`, and (for safety) rely on module-level `implicit none` covering contained procedures — but verify.
- Compile with `-fimplicit-none` so the compiler **enforces** it globally regardless of source — a cheap safety net.
- `-Wall -Wextra` flags unused/uninitialized symbols that often reveal a stray implicit variable.

**Warning signs:**
A computed value stays at 0 or garbage; `-fimplicit-none` suddenly produces "Symbol has no IMPLICIT type" errors (good — those are real bugs).

**Phase to address:** P1 (set `-fimplicit-none` in the dev Makefile flags), enforced everywhere.

---

### A5: Uninitialized variables read as garbage

**What goes wrong:**
Fortran does **not** zero-initialize local variables. An accumulator (`city_sum`), a max-tracker (`hottest`), or a per-cell offset used before assignment contains indeterminate memory — giving plausible-but-wrong city averages or a "hottest cell" that is noise. This is the single most common source of "works sometimes" bugs.

**Why it happens:**
No default initialization for locals; developers assume zero (as in many other languages). Also: initializing in the *declaration* (`real :: s = 0.0_dp`) gives the variable the `save` attribute, so it is **not** reset on the next call — a different subtle bug in a routine called per timestep/scenario.

**How to avoid:**
- Explicitly initialize accumulators at the **start of the executable body**, not in the declaration, for anything inside a routine called more than once.
- During development always compile with `-fcheck=all -Wall -Wextra -finit-real=snan -finit-integer=-99999`. `-finit-real=snan` makes any use of an uninitialized real **trap** instead of silently propagating.
- Initialize "hottest/coolest" trackers from the first cell, not from an arbitrary `0.0`/`huge`.

**Warning signs:**
City-average or extremes change run-to-run; `-finit-real=snan` produces a floating-point exception (it just found your bug); a "min" cell stuck at 0.

**Phase to address:** P1 (dev flags), P7 (summary aggregations — accumulators live here).

---

### A6: Array-bounds and 1-based indexing bugs

**What goes wrong:**
Fortran arrays are **1-based** and **column-major**. Off-by-one on grid edges (writing `grid(nx+1, j)`), or iterating in row-major order (`do i; do j` with `i` as the outer/contiguous loop) causes either out-of-bounds writes (silent memory corruption without checks) or cache-thrashing slowness. Neighbor lookups for any future smoothing are the prime offender.

**Why it happens:**
Developers coming from C/Python assume 0-based and row-major; Fortran is the opposite on both. Without `-fcheck=bounds`, out-of-range writes corrupt adjacent data silently.

**How to avoid:**
- Always develop with `-fcheck=all` (includes `-fcheck=bounds`); it turns silent corruption into a clear runtime error with the offending index.
- Loop with the **first index innermost** for contiguous access: `do j = 1, ny;  do i = 1, nx;  ... grid(i,j) ...`.
- Use array syntax (`grid % temp = ...`) or `do concurrent` where possible to avoid manual index errors.

**Warning signs:**
`-fcheck=all` reports "Index 'N' out of bounds"; results change when an unrelated array is resized (corruption); surprisingly slow grid loops.

**Phase to address:** P2 (grid type + iteration order), P5 (neighbor/time loops).

---

### A7: Assumed-shape arrays passed without an explicit interface

**What goes wrong:**
Passing an allocatable or assumed-shape array (`real(dp) :: a(:,:)`) to a procedure that is **not** in a module (or otherwise lacking an explicit interface) corrupts the array descriptor — the callee sees wrong shape/bounds. Symptoms range from garbage to crashes.

**Why it happens:**
Assumed-shape dummies require the compiler to know the interface at the call site. External (non-module) procedures have only an implicit interface, which can't carry shape info.

**How to avoid:**
- Put **all** procedures in modules and `use` them — this is the modern-Fortran default and gives automatic explicit interfaces. The project already plans a module layout, so just keep every subroutine/function inside a module.
- Never write a bare external subroutine that takes `(:)`/`(:,:)` arrays.

**Warning signs:**
`-fcheck=all` shape-mismatch errors; correct results only when arrays are passed as explicit-shape `(nx,ny)`; gfortran warning "Procedure ... called with implicit interface".

**Phase to address:** P1 (module-everything convention), P2/P4 (array-passing routines).

---

### A8: Allocatable lifecycle — leaks, double-free, and shape mismatch

**What goes wrong:**
Allocating the grid each scenario/timestep without deallocating leaks memory; allocating an already-allocated array errors at runtime; `allocate` with the wrong extent silently changes the grid size. Re-allocating inside the diurnal/scenario loop is the trap.

**Why it happens:**
Manual `allocate`/`deallocate` is error-prone; people forget that re-`allocate` of an allocated array is an error (use `allocated()` guard or rely on automatic reallocation-on-assignment).

**How to avoid:**
- Prefer **allocate once** (grid sized at load in P2), reuse across timesteps/scenarios; only the *values* change.
- Use `allocate(... , stat=ierr)` and check `ierr`; guard with `if (allocated(x)) deallocate(x)`.
- Modern Fortran auto-deallocates allocatables on scope exit and auto-reallocates on intrinsic assignment — lean on that instead of manual management where possible.
- `-fcheck=all` plus `valgrind` (or `-fsanitize=address` with recent gfortran) for leak/double-free detection.

**Warning signs:**
"Attempting to allocate already allocated variable" runtime error; growing memory across scenarios; grid extents that don't match the data file.

**Phase to address:** P2 (allocation strategy), P5/P6 (loops that might re-allocate).

---

### A9: CSV formatting — locale decimals, fixed-width truncation, `*****`

**What goes wrong:**
Three classic output failures: (1) Using a **fixed-width** edit descriptor like `F6.2` for a value that overflows the field prints `******` (asterisks) instead of the number — common when a scenario pushes feels-like above 99.99 or negative. (2) Some locales/format choices emit a **comma** decimal separator, breaking CSV parsing in Excel/Python/gnuplot. (3) List-directed output (`write(*,*)`) inserts unpredictable leading spaces and its own field widths — not real CSV.

**Why it happens:**
Fortran formatted I/O is field-width based, not free. Default list-directed output isn't comma-delimited. Decimal-comma is a real-world locale hazard.

**How to avoid:**
- Use generous, explicit formats and **comma delimiters**, e.g. `write(u,'(A,",",F0.3,",",F0.3)') name, t_air, feels` — `F0.3` chooses minimum width so it never prints `*****`.
- Or use `write(u, '(*(g0,:,","))') ...` (modern `g0` + unlimited format) for clean, width-free CSV with commas.
- Emit `.` decimals: Fortran's default is `.`; do **not** set `DECIMAL='COMMA'` in `open`/`write`. If portability is a worry, explicitly `decimal='POINT'`.
- Write a header row; quote any string field (district names) that could contain a comma.
- Open the file once with an explicit unit and `newunit=`; check `iostat`.

**Warning signs:**
`*****` in output cells; Excel loads everything into one column or misreads numbers; gnuplot/Python `float()` errors; ragged columns.

**Phase to address:** P7 (CSV writer), with a column-spec decided up front.

---

### A10: Non-portable / fragile namelist (or ad-hoc) input parsing

**What goes wrong:**
Reading HCMC district data via Fortran `namelist` or hand-rolled parsing breaks on: trailing whitespace, tab vs space, missing/extra fields, `/` terminator quirks, or a comma-decimal in the input file. A single malformed row silently shifts every subsequent field, loading the wrong density into the wrong cell — a *scientific* error caused by an *I/O* bug.

**Why it happens:**
`namelist` syntax is finicky and compiler-variant in edge cases; list-directed reads happily mis-align on a bad delimiter; no schema validation by default.

**How to avoid:**
- Prefer a **simple, well-specified delimited file** (CSV/TSV with a header) over `namelist` for the district data; parse explicitly and validate each field.
- Always read with `iostat=` and `iomsg=`; on error, print the offending line number and stop — never continue with partial data.
- Validate ranges at load (P2): humidity 0–100%, temperature within a sane HCMC envelope, density 0–1 — fail loudly on violation.
- Keep the data file format documented next to the code.

**Warning signs:**
Reads "succeed" but values are shifted by one column; a malformed row produces NaN/huge downstream; results change when you reorder columns.

**Phase to address:** P2 (data loading + validation).

---

## B. Critical Pitfalls — Scientific / Modeling

### B1: Applying the NOAA heat index outside its valid range (THE headline science pitfall)

**What goes wrong:**
The NWS/NOAA **Rothfusz regression** for heat index is only valid for **air temperature ≥ ~80 °F (≈26.7 °C)** and **relative humidity ≥ 40%**, producing a result at/above ~80 °F. Applied below those thresholds it returns **nonsense** — it can report a "feels-like" temperature *lower* than the actual air temperature, or wildly off values. For HCMC this is not a corner case: **early-morning and night-time temperatures routinely dip to ~24–26 °C** — i.e. right at or below the threshold — which is *exactly* when the project most wants believable numbers (the nocturnal UHI gap is the signature result). Blindly running Rothfusz at 3 a.m. will produce a broken night map.

**Why it happens:**
The regression is a polynomial fit valid only in its training envelope; developers copy the equation without copying the **guard conditions** NWS documents. HCMC's humid nights sit near the lower edge, so the failure shows up precisely in the headline scenario.

**How to avoid:**
- Implement the **full NWS algorithm**, not just the regression (P3):
  1. First compute the **simple Steadman formula** and average with T: `HI_simple = 0.5*(T + 61 + (T-68)*1.2 + RH*0.094)` then average with T (T in °F).
  2. **Only if** that result ≥ 80 °F, apply the full Rothfusz regression.
  3. Apply the documented **adjustments**: subtract when RH < 13% & T 80–112 °F; add when RH > 85% & T 80–87 °F.
  4. Below 80 °F, the apparent temperature ≈ air temperature (no significant heat-index amplification) — return T, do not extrapolate the polynomial.
- Add an explicit **validity-range guard** with a comment citing the 80 °F / 40% RH limits; log/flag any cell evaluated below threshold so it is visible in QA.
- Decide units once (compute internally in °F per the formula, present in °C) and convert with `_dp` literals (ties to A1).

**Warning signs:**
Night/early-morning feels-like temps **below** the air temperature in a humid city; a discontinuity/kink at the 80 °F boundary if the two-branch logic is wrong; heat-index values that decrease as humidity rises (impossible in the valid range).

**Phase to address:** P3 (heat-index module — implement the branch + guard), re-verified in P5 (because night is where the range is breached).

---

### B2: Getting the diurnal UHI pattern backwards (UHI gap is largest at NIGHT)

**What goes wrong:**
A modeler intuitively makes the urban–rural temperature gap **largest at mid-afternoon** (peak sun) — which is **wrong** and destroys the project's core value. The canopy-layer UHI is **greatest at night / pre-dawn**, under clear calm skies: urban concrete/asphalt (huge heat capacity) stores solar energy by day and **releases it slowly after sunset**, while rural/vegetated land cools rapidly by radiation. By day the urban–rural air-temperature difference is often small or even slightly negative; the gap **opens up at night**. If the model peaks the gap at noon, the signature scientific result is inverted.

**Why it happens:**
Confusing "hottest absolute temperature" (afternoon) with "largest urban–rural *difference*" (night). They are different quantities. Also conflating *surface* temperature (which does peak by day) with *air* temperature UHI (which peaks at night) — see B6.

**How to avoid:**
- Make the **UHI offset time-dependent** (P4/P5): the thermal-mass / heat-release term must be **small or zero at mid-afternoon and maximal at night/pre-dawn**. Drive it by a diurnal function (e.g. offset ∝ stored daytime heat released after sunset), not by instantaneous solar input.
- Write an explicit **acceptance test**: for identical baseline weather, `gap_night > gap_afternoon` must hold for dense-vs-rural cells. Fail the build/QA if not.
- Document the mechanism (radiative cooling + heat storage + nocturnal inversion) in a comment so future edits don't "fix" it backwards.

**Warning signs:**
Modeled urban–rural gap maxes out at the afternoon timestep; night map shows urban and rural nearly equal; tree/water cooling appears strongest at noon instead of persisting into night.

**Phase to address:** P5 (day–night cycle — this is the make-or-break phase), with the offset shape designed in P4.

---

### B3: Unphysical or double-counted UHI offsets

**What goes wrong:**
The UHI adjustment is applied **on top of** a heat index that already encodes humidity, and the building/tree/water terms are tuned independently, so effects **double-count** or stack into absurd magnitudes (e.g. a +8 °C urban offset on top of a +6 °C humidity heat-index bump → a 14 °C surcharge). Or proximity-to-water both *lowers temperature* and *raises humidity* (which raises heat index), and only one is modeled, so water can paradoxically make a cell "feel" hotter.

**Why it happens:**
The feels-like value and the UHI offset are designed in separate phases without a shared physical budget; each knob is tuned to "look right" alone. Sign/coupling between humidity and water proximity is easy to get inconsistent.

**How to avoid:**
- Define a **single, explicit temperature budget** (P4): `feels = heat_index(T_air_adjusted, RH_adjusted)` where UHI modifies the *inputs* (air temp, local humidity) **once**, rather than adding a second post-hoc offset to the already-computed heat index. Decide and document whether each driver acts on T, on RH, or on the final value — and never on two at once.
- Cap each driver's contribution to a physically plausible range (urban canopy UHI is typically a few °C, single digits — not tens).
- Keep humidity↔water coupling consistent: if water lowers T it may *raise* RH; model both or neither, and sanity-check that waterfront cells end up cooler overall.

**Warning signs:**
Feels-like surcharges in the double digits of °C; waterfront cells coming out hotter than inland; removing one driver changes results far more than physically reasonable; offsets that don't sum to a sane city-wide envelope.

**Phase to address:** P4 (define the budget), cross-checked in P3 (so the two layers compose cleanly).

---

### B4: Unrealistic HCMC baseline values

**What goes wrong:**
Seeding the grid with implausible weather (e.g. 40 °C / 20% RH, or a uniform 30 °C everywhere) yields a heat map that is internally consistent but **obviously wrong** to anyone who knows HCMC — undermining the "scientifically believable" goal. HCMC is tropical monsoon: typical daytime highs ~31–35 °C, night lows ~24–26 °C, RH ~60–95% (higher at night and in wet season). Picking dry-climate numbers also pushes cells into the heat-index valid-range edge incorrectly (ties to B1).

**Why it happens:**
Placeholder/synthetic data never replaced with realistic district values; copying mid-latitude examples; not cross-checking against known HCMC climate norms.

**How to avoid:**
- Seed P2 district data from **realistic HCMC ranges** (document the source/justification in the data file header): District 1 (dense, hot), Thu Duc (mixed), Can Gio (coastal/mangrove, cooler), etc.
- Add **range-validation at load** (overlaps A10): reject temperatures, humidity, density outside a documented HCMC envelope.
- Sanity-check the terminal summary against intuition: city-average feels-like in the low-to-mid 30s °C by day; Can Gio/waterfront coolest; District 1 core hottest.

**Warning signs:**
Night humidity below ~50% in a coastal tropical city; absolute feels-like temps that no one in HCMC would recognize; uniform values across very different districts; rural coastal cell hotter than the urban core.

**Phase to address:** P2 (data seeding + validation), sanity-checked in P7 (summary).

---

### B5: Non-apples-to-apples scenario comparison

**What goes wrong:**
The what-if comparison ("add trees" vs "more concrete") changes **more than one variable at a time**, or compares scenarios evaluated at **different timesteps / baseline weather**, so the reported "cooling from trees" conflates the intervention with an unrelated change. The headline number ("+X trees → −Y °C") becomes meaningless.

**Why it happens:**
Scenarios are built by editing the grid in place and re-running, without freezing the baseline; the diurnal loop and scenario loop interact so scenarios get sampled at different times; random/initialization differences leak in.

**How to avoid:**
- Hold **everything constant except the single varied driver** (P6): same baseline weather, same timestep set, same grid geometry, same seed. Change only tree density (or only building density).
- Compute deltas **per cell and per timestep** against the *same* baseline, then aggregate — don't compare a day baseline to a night scenario.
- Make the baseline immutable: copy the grid for each scenario rather than mutating the shared one (ties to A8 allocatable handling).
- Report the comparison methodology alongside the number.

**Warning signs:**
Scenario deltas that flip sign between runs; "cooling" that exceeds the physically modeled tree term (means something else moved); baseline values differing between two scenarios that should share them.

**Phase to address:** P6 (scenario engine), relying on a clean immutable baseline from P2.

---

### B6: Conflating air temperature with surface / feels-like temperature

**What goes wrong:**
The three quantities — **air (canopy) temperature**, **land-surface temperature (LST)**, and **apparent/feels-like (heat index)** — are mixed. Notably, **surface UHI peaks during the day** (sun-baked asphalt) while **air-temperature/canopy UHI peaks at night** (B2). If the model labels its output "surface temperature" but applies a night-peaking air-UHI, or feeds a feels-like value into a place expecting raw air temp, the physics and the labels disagree.

**Why it happens:**
Popular UHI imagery (thermal satellite maps) shows *surface* temperature, which behaves oppositely to air temperature diurnally; it's easy to import that day-peaking intuition (causing B2) or to mislabel the output.

**How to avoid:**
- Decide explicitly (P3/P4) that this model computes **air temperature → apparent (feels-like) temperature**, with a **canopy-layer (air) UHI that peaks at night**. State it in code comments, CSV column names, and the summary.
- Keep variable names unambiguous: `t_air`, `feels_like`, never a generic `temp`.
- Don't borrow day-peaking *surface*-UHI magnitudes for the *air*-UHI term.

**Warning signs:**
CSV/summary labeled "surface temperature" but gap peaks at night (or labeled air temp but peaks at noon); a single `temp` variable doing double duty; magnitudes borrowed from satellite-LST studies.

**Phase to address:** P3/P4 (define the quantity and naming), enforced in P7 (column labels).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-coding district data as constants instead of loading a file | Faster first run | Violates a stated requirement; can't edit scenarios without recompiling | Never — requirement says load from file (P2) |
| `write(*,*)` list-directed "CSV" | Quick output | Not real CSV (spaces, widths); breaks external parsing | Only for throwaway debug prints, never the deliverable |
| Skipping the Steadman/below-80°F branch of heat index | Less code in P3 | Broken night map (B1) — kills core value | Never for this project (night is the headline) |
| Post-hoc additive UHI offset on the final heat index | Simple to wire | Double-counting (B3); hard to keep physical | Only if a single explicit budget is documented |
| Manual `allocate`/`deallocate` per timestep | Feels explicit | Leak/double-free risk (A8) | Acceptable if `stat=`-checked; prefer allocate-once |
| Building with `make` glob order, no explicit deps | Less Makefile typing | Stale-`.mod` heisenbugs (A3) | Only with ≤2 modules; declare deps as it grows |
| Developing without `-fcheck=all` for speed | Marginally faster runs | Silent corruption/uninit bugs ship | Acceptable for a final timed/release build only, never during dev |

## "Looks Done But Isn't" Checklist

- [ ] **Heat index:** Runs without crashing — but verify it uses the **two-branch** algorithm and returns ~air-temp (not nonsense) for night cells below ~26.7 °C / where HI < 80 °F (B1).
- [ ] **Day–night cycle:** Produces a night map — but verify `urban_rural_gap(night) > urban_rural_gap(afternoon)` for identical baseline weather (B2). Add this as an automated assertion.
- [ ] **UHI offsets:** Cells differ — but verify total feels-like surcharge stays in single-digit °C and waterfront cells end up **cooler**, not hotter (B3).
- [ ] **CSV:** File opens — but verify no `*****`, `.` decimal separators, a header row, and that Python/gnuplot parse every column (A9).
- [ ] **Data loading:** Program reads the file — but verify a malformed/short row is **rejected loudly**, not silently column-shifted (A10), and all values pass HCMC range checks (B4).
- [ ] **Precision:** Numbers look reasonable — but verify they don't change between `-O0` and `-O2` (no unsuffixed literals, A1) and that `-finit-real=snan` runs clean (no uninit reads, A5).
- [ ] **Scenarios:** Deltas reported — but verify each scenario changed exactly one driver against an immutable shared baseline (B5).
- [ ] **Build:** `make` succeeds — but verify a `make clean && make` from scratch also succeeds (no stale-`.mod` dependence, A3).
- [ ] **Labels:** Output exists — but verify columns say `t_air` vs `feels_like` unambiguously and the documented quantity matches the night-peaking physics (B6).

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| A1 Precision-loss literals | P1 (kinds module), P3/P4 | Output identical across `-O0`/`-O2`; grep for bare real literals |
| A2 Mixed-kind / integer division | P2, P4 | Hand-checked cell matches code; no exactly-zero offsets |
| A3 Compile-order / stale `.mod` | P1 | `make clean && make` from scratch passes; explicit deps in Makefile |
| A4 Missing `implicit none` | P1 | Build with `-fimplicit-none` passes; no implicit-type symbols |
| A5 Uninitialized variables | P1, P7 | `-fcheck=all -finit-real=snan` run is clean |
| A6 Bounds / 1-based / column-major | P2, P5 | `-fcheck=all` reports no out-of-bounds; contiguous loop order |
| A7 Assumed-shape w/o interface | P1, P2/P4 | All procedures in modules; no implicit-interface warnings |
| A8 Allocatable lifecycle | P2, P5/P6 | `valgrind`/ASan clean; allocate-once strategy |
| A9 CSV formatting/locale | P7 | External parser reads all columns; no `*****`; `.` decimals |
| A10 Input parsing portability | P2 | Malformed row rejected with line number; range-validated |
| B1 Heat-index valid range | P3 (impl), P5 (verify) | Night cells return sane values; two-branch logic tested at boundary |
| B2 Diurnal UHI backwards | P5 (design in P4) | Asserted `gap_night > gap_afternoon` for same weather |
| B3 Unphysical/double-counted offset | P4 (budget), P3 | Single-digit °C surcharge; waterfront cooler; one budget documented |
| B4 Unrealistic HCMC baseline | P2 (seed/validate), P7 | Summary matches HCMC intuition; range checks pass |
| B5 Non-apples scenarios | P6 | One driver varied vs immutable baseline; deltas reproducible |
| B6 Air vs surface vs feels-like | P3/P4 (define), P7 (labels) | Columns/labels match night-peaking air-UHI physics |

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| B2 Diurnal pattern inverted | HIGH | Rework the time-dependence of the UHI offset (P4/P5); it touches the core model — cheaper to design right first with the assertion in place |
| B1 Heat index out of range | MEDIUM | Add the Steadman/below-80°F branch + guard in P3; re-run night maps |
| A1 Precision-loss literals | LOW–MEDIUM | Mechanical: suffix every literal `_dp`; verify with `-O0`/`-O2` diff |
| A3 Stale `.mod` | LOW | Add `*.mod` to `clean`; declare explicit Makefile deps; rebuild clean |
| A9 CSV formatting | LOW | Switch to `F0.x`/`g0` formats with comma delimiters; add header |
| B3 Double-counted offset | MEDIUM | Refactor to a single input-modifying budget (P4); re-tune once |

## Sources

- NOAA / NWS Weather Prediction Center — *The Heat Index Equation* and *Calculating the Heat Index* (Rothfusz regression; valid range T ≥ 80 °F & RH ≥ 40%; Steadman simple-formula branch; low/high-RH adjustments). https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml and https://www.wpc.ncep.noaa.gov/heat_index/details_hi.html — **HIGH confidence (authoritative/curated)**
- NWS SR 90-23 Technical Attachment, *The Heat Index "Equation"* (Rothfusz). https://www.weather.gov/media/ffc/ta_htindx.PDF — **HIGH**
- Wikipedia, *Urban heat island* (nocturnal UHI: gap larger at night, clear/calm skies; concrete heat-capacity ~2000× air; nocturnal inversion; vegetation cooling dominant in 24-h/early-morning averages). https://en.wikipedia.org/wiki/Urban_heat_island — **MEDIUM–HIGH (cross-checked with AMS/Nature below)**
- AMS *Journal of Applied Meteorology and Climatology* — *Thermal Effects of Urban Canyon Structure on the Nocturnal Heat Island* (UHI greatest at night via differential surface cooling / heat storage). https://journals.ametsoc.org/jamc/article/43/12/1899 — **HIGH**
- Nature Communications — *On the influence of density and morphology on the Urban Heat Island intensity*. https://www.nature.com/articles/s41467-020-16461-9 — **HIGH**
- gfortran documentation — debugging flags `-fcheck=all`, `-finit-real=snan`, `-finit-integer`, `-fimplicit-none`, `-Wall`, `-Wextra`; module `.mod` compile-order behavior. (GCC manual) — **HIGH (curated)**
- Modern Fortran best-practice consensus (Fortran-lang community guidance) — `implicit none` everywhere, module-everything for explicit interfaces, allocate-once, kinds via `iso_fortran_env`/`selected_real_kind`. https://fortran-lang.org/ — **MEDIUM–HIGH (curated/community)**

---
*Pitfalls research for: Modern Fortran UHI / heat-index simulator (Ho Chi Minh City)*
*Researched: 2026-06-28*
