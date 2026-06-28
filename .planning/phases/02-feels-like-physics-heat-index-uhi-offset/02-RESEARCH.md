# Phase 2: Feels-Like Physics (Heat Index + UHI Offset) - Research

**Researched:** 2026-06-28
**Domain:** Modern Fortran scientific computing — NWS heat-index kernel + additive UHI temperature offset, on an existing fpm + test-drive scaffold
**Confidence:** HIGH (science formulas verified against NWS algorithm and recomputed numerically this session; Fortran patterns mirror existing Phase-1 code read this session)

## Summary

This phase adds two `elemental pure` physics kernels on top of the Phase-1 grid/IO foundation:
a **NWS heat index** (`heat_index_mod`) and an **additive UHI offset** (`uhi_mod`), then wires
`feels_like(cell) = max(HeatIndex(t_base + ΔT_UHI, rh_cell), t_air)` into the existing
`app/main.f90` cell loop and locks the dense-urban > green/waterfront/rural ordering with a
test-drive suite. All eleven decisions D-01..D-11 are locked; this research is purely about
*how* to implement them correctly in modern Fortran, not whether to.

The science is well-specified and was recomputed this session: the canonical NWS algorithm
runs in °F (simple Steadman, averaged with T; if that average ≥ 80 °F, full Rothfusz + the two
RH adjustments), and the additive budget `ΔT = w_build·B + w_urban·U − w_tree·V − w_water·Wprox`
with `Wprox = exp(−water_km/d0)` spans ≈ −4.5 … +4.0 °C at the Phase-1 weights. A full
pipeline run against the real seed data confirms the headline ordering holds even with per-cell
RH varying (industrial/D1/D7 dense-urban cells rank hottest; park/Can Gio/rural coolest).

**Primary recommendation:** Build three small modules in dependency order — extend
`constants_mod` with `c_to_f`/`f_to_c` elemental helpers, add `heat_index_mod` (pure NWS in °F)
and `uhi_mod` (additive budget) consuming only scalar `real(wp)`/`logical` args (not the derived
type), add a tiny `feels_like` wrapper, add `d0` to `coeffs_t` + the namelist, compute feels-like
locally in the driver loop (do **not** store on `type(cell)`), and add three test-drive suites
mirroring `test/test_io.f90`. Pass strict dev flags via `fpm test --flag "..."`, never via
`fpm.toml` profiles.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Hybrid base. `feels_like(cell) = HeatIndex(t_base + ΔT_UHI, rh_cell)` — temperature
  base is the **uniform** `coeffs%t_base` for every cell; relative humidity is **per-cell**
  `cell%rh`. Spatial temperature variation comes *only* from the land-cover offset.
- **D-02:** `w_water` acts on the **temperature input only** (via the offset). Per-cell `rh` is
  consumed as-is — water proximity does NOT additionally raise RH in code (avoids B3 double-count).
- **D-03:** Single temperature budget, applied once:
  `ΔT_UHI = w_build·B + w_urban·U − w_tree·V − w_water·Wprox`, added to the heat-index
  **temperature input** (NOT a second post-hoc offset on the final heat index). Weights
  `w_build=3.0, w_urban=1.0, w_tree=2.5, w_water=2.0`; offset spans ≈ −4.5 … +4 °C.
- **D-04:** Water-proximity = continuous exponential decay `Wprox = exp(−water_km/d0)` (pulls
  REFN-02 into v1).
- **D-05:** Add tunable scale length `d0` (default ≈ 2.5 km, Claude's discretion ~2–3 km) to
  `data/coeffs.nml`, loaded at runtime via `read_coeffs_nml`.
- **D-06:** No diurnal scaling in Phase 2. Offset evaluated at `m = 1` (full offset). The
  `m_*` coefficients belong to Phase 3 — Phase 2 must NOT consume them.
- **D-07:** Full NWS two-branch algorithm: simple Steadman when result < 80 °F; full Rothfusz
  at/above 80 °F; **plus both adjustments** — add when RH > 85 % & T 80–87 °F; subtract when
  RH < 13 % & T 80–112 °F.
- **D-08:** Compute internally in °F with canonical coefficients; convert °C↔°F at the boundary
  (`F = C·9/5+32`). Every literal carries a `_wp` suffix. Never mix °C/°F coefficient variants.
- **D-09:** Floor: `feels_like = max(HeatIndex(...), t_air)` so a cool/night cell never returns
  feels-like below air temperature. Verified by 80 °F boundary test + NWS reference values.
- **D-10:** UHI-02 test uses synthetic controlled archetypes built **inside the test**
  (industrial / District-1 core / park / Can Gio / rural fringe); assert rank ordering. Robust
  to seed-data edits; tests the *model*, not the data file.
- **D-11:** Property-monotonicity checks alongside the ordering assert: ↑building → ↑feels-like,
  ↑tree → ↓feels-like, ↑Wprox → ↓feels-like, urban > rural. Verify by rank/sign, not absolute °C.

### Claude's Discretion

- Module names/APIs (roadmap suggests `heat_index_mod`, `uhi_mod`), derived-type field names,
  exact `d0` default within ~2–3 km, and how feels-like is surfaced on the existing console
  output. Kernels must be **`elemental pure`, no global state**, consuming `grid_t` + `coeffs_t`
  (Phase-1 integration contract).

### Deferred Ideas (OUT OF SCOPE)

- Diurnal multiplier `m(t)` and multi-timestep evaluation — Phase 3 (TIME-01/TIME-02).
- What-if scenarios / immutable-baseline copy-then-mutate — Phase 3 (SCEN-01/SCEN-02).
- CSV export of feels-like / UHI offset columns — Phase 4 (OUT-01).
- Humidex toggle (REFN-01), smooth cosine diurnal curve (REFN-03), more districts (REFN-04),
  seasonal runs (REFN-05) — v2.
- Tuning weights so the night gap lands in ~3–8 °C — Phase-3 calibration concern. Phase 2 only
  needs correct *ordering* at full offset, not a calibrated night-gap magnitude.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HEAT-01 | Per-cell feels-like from air temp + RH | `heat_index_mod` elemental kernel + °C↔°F helpers; feels-like wrapper consuming `t_base+ΔT` and per-cell `rh` (Code Examples §Heat Index, §Feels-like wrapper). |
| HEAT-02 | Range guard — Steadman <80 °F / Rothfusz ≥80 °F; never below air temp; boundary test at 80 °F | Exact two-branch algorithm + boundary behavior documented (Pitfall 1, Code Examples §Heat Index); floor `max(HI, t_air)` (D-09); reference values incl. just-below-boundary point (NWS Reference Values table). |
| UHI-01 | Additive offset: building/urban warm, tree/water-proximity cool; one budget, single-digit °C per driver | Single-budget kernel `uhi_offset` (Code Examples §UHI offset); budget magnitude analysis confirms −4.5…+4 °C range (Numeric Gotchas). |
| UHI-02 | Dense treeless urban ranks hotter than green/waterfront/rural — automated test | Synthetic-archetype test pattern (D-10) + monotonicity checks (D-11); full-pipeline ordering verified against seed data this session (Ordering Verification table). |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Heat-index arithmetic | Domain/Physics (`heat_index_mod`) | Foundation (`constants_mod` for °C↔°F + regression coeffs) | Pure data-in/data-out; no I/O, no state — must be elemental & unit-testable. |
| UHI offset arithmetic | Domain/Physics (`uhi_mod`) | Foundation (weights flow from `coeffs_t`) | Same — pure budget over scalar inputs. |
| feels-like composition (`max(HI(t_base+ΔT, rh), t_air)`) | Domain/Physics (thin wrapper) | — | Composes the two kernels + floor; keeps the formula in one named place for Phase 3/4 reuse. |
| `d0` config loading | Data/IO (`read_coeffs_nml`) + Foundation (`coeffs_t` field) | — | Tunable-without-recompile (GRID-04); namelist round-trip already owns coefficients. |
| Driver evaluation + console print | Driver (`app/main.f90`) | Domain (calls the wrapper) | Orchestration only; no physics logic in the driver. |
| Ordering / monotonicity assertions | Test (`test/test_*.f90`) | Domain (calls kernels) | Locks the headline science invariant in CI via test-drive. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| gfortran (GCC) | 16.1.0 (Homebrew) | Compiler | Already installed/verified this session `[VERIFIED: gfortran --version]`; full F2018 support. |
| fpm | 0.13.0 | Build/test/run driver | Already in use `[VERIFIED: fpm --version]`; auto-resolves module compile order. |
| test-drive | 0.6.0 | Unit test framework | Already a `[dev-dependencies]` entry in `fpm.toml` `[VERIFIED: fpm.toml]`; Phase-1 tests use it. |
| iso_fortran_env | intrinsic | `real64` kind via `kinds_mod` (`wp`) | Existing project convention `[VERIFIED: src/kinds.f90]`. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | — | — | No new dependencies required for this phase. Standard intrinsics (`exp`, `sqrt`, `abs`, `max`, `merge`) cover everything. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure °F NWS kernel + boundary conversion (D-08) | A direct °C-coefficient Rothfusz variant | LOCKED OUT by D-08 — mixing °C/°F coefficient sets is the classic heat-index bug (PITFALLS A1/B1). Do not introduce. |
| Passing scalar args to elemental kernels | Passing `type(coeffs_t)` into the elemental function | A scalar derived type with only scalar components is technically legal in an elemental procedure, but passing plain `real(wp)`/`logical` scalars is safer, matches ARCHITECTURE.md example signatures, and keeps unit tests trivial. **Recommend plain scalars.** |
| Computing feels-like locally in driver | Adding a `feels_like` field to `type(cell)` | A scalar field on `cell` cannot hold Phase-3's multiple timesteps; storing now would need rework. Compute via the pure wrapper instead (see Wiring). |

**Installation:** No new packages. test-drive is already vendored by fpm from `fpm.toml`.

**Version verification (this session):**
- `gfortran` → `GNU Fortran (Homebrew GCC 16.1.0) 16.1.0` `[VERIFIED: gfortran --version]`
- `fpm` → `Version: 0.13.0, alpha` `[VERIFIED: fpm --version]`
- `test-drive` → pinned `tag = "v0.6.0"` in `fpm.toml` `[VERIFIED: fpm.toml]`

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| test-drive | fpm/git (github.com/fortran-lang/test-drive) | established (fortran-lang org) | n/a (git dep) | github.com/fortran-lang/test-drive | OK | Already installed in Phase 1 — no new install this phase |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

This phase installs **no new external packages**. The only dependency, `test-drive`, was added
and used in Phase 1 and is pinned to a tag from the official `fortran-lang` GitHub org.

## Architecture Patterns

### System Architecture Diagram

```
data/coeffs.nml ──read_coeffs_nml──> coeffs_t {w_build,w_urban,w_tree,w_water, d0(NEW), t_base, rh_base, ...}
data/hcmc_districts.csv ──read_grid_csv──> grid_t % cells(:,:) {t_air, rh, water_km, building, tree, is_urban, occupied}
        │                                              │
        └───────────────────┬──────────────────────────┘
                            ▼  app/main.f90  (per occupied cell)
            ┌──────────────────────────────────────────────────────────┐
            │ uhi_offset(building, tree, water_km, is_urban,            │  uhi_mod  (elemental pure)
            │            w_build,w_urban,w_tree,w_water, d0)  → ΔT °C   │
            │                         │                                  │
            │            t_adj_c = coeffs%t_base + ΔT     (D-01, D-03)  │
            │                         ▼                                  │
            │ heat_index(c_to_f(t_adj_c), rh_cell) → HI °F   (D-07,D-08)│  heat_index_mod (elemental pure)
            │                         ▼                                  │
            │ feels_c = max(f_to_c(HI), t_adj_c)             (D-09)     │  feels-like wrapper
            └──────────────────────────┬───────────────────────────────┘
                                       ▼
                         console print (extend existing District List line)
                                       │
            test/test_heat_index.f90, test/test_uhi.f90, test/test_ordering.f90  (test-drive)
              └─ assert NWS reference values, 80°F boundary, archetype ordering, monotonicity
```

### Recommended Project Structure
```
src/
├── kinds.f90          # wp = real64                         (exists)
├── constants.f90      # ranges + ADD: c_to_f/f_to_c + NWS regression coeffs
├── grid.f90           # cell / grid_t / coeffs_t — ADD d0 field to coeffs_t
├── io.f90             # read_coeffs_nml — ADD d0 to namelist + copy
├── heat_index.f90     # NEW heat_index_mod (elemental pure, °F internal)
├── uhi.f90            # NEW uhi_mod (elemental pure additive budget)
└── feels.f90          # NEW feels_mod (thin elemental wrapper) — optional but recommended
app/
└── main.f90           # wire feels-like into existing cell loop + print
test/
├── test_io.f90        # exists (mirror its harness)
├── test_e2e_load.f90  # exists
├── test_heat_index.f90  # NEW — reference values + boundary
├── test_uhi.f90         # NEW — budget signs + monotonicity
└── test_ordering.f90    # NEW — synthetic-archetype ranking (UHI-02)
```
`fpm` `auto-tests = true` discovers any `test/test_*.f90` program automatically — no `fpm.toml`
edit needed to register new suites `[VERIFIED: fpm.toml build table]`.

### Pattern 1: Elemental pure kernel in modules (mirror existing style)
**What:** Each kernel is `elemental pure function`, in a `private` module with one explicit
`public` export, `use ..., only:`. Matches `grid_mod`/`io_mod` exactly.
**When to use:** Both physics kernels.
**Example:** see Code Examples §Heat Index and §UHI offset below.

### Pattern 2: Logical → real for the urban flag (avoid A2 integer-division analog)
**What:** `is_urban` is `logical`. To use it as `U ∈ {0,1}` in the budget, convert with the
elemental intrinsic `merge`: `U = merge(1.0_wp, 0.0_wp, is_urban)`. Never multiply a logical or
rely on implicit conversion.

### Pattern 3: Compute-locally feels-like, expose a pure wrapper for reuse
**What:** Provide `elemental pure function feels_like_c(t_base, rh, building, tree, water_km,
is_urban, w_build, w_urban, w_tree, w_water, d0) result(feels_c)` that composes both kernels +
the floor. Phase 3 calls the same function per timestep (just multiplying ΔT by `m(t)` upstream).
Driver computes it inline per cell; nothing is stored on `type(cell)` yet.

### Anti-Patterns to Avoid
- **Second post-hoc offset on the final heat index** — violates D-03/B3 (double-count). The
  offset modifies the *temperature input* once, before the heat index runs.
- **Storing a scalar `feels_like` on `type(cell)`** — breaks under Phase-3 multi-timestep; compute
  via the wrapper instead.
- **Bare real literals** (`0.5`, `9.0/5.0`) — every literal must be `_wp` (A1; Rothfusz has large
  opposing terms where single-precision rounding is visible).
- **Consuming `m_morning`/`m_afternoon`/etc. in Phase 2** — forbidden by D-06.
- **I/O or `error stop` inside an elemental kernel** — illegal in elemental procedures and breaks
  testability (ARCHITECTURE anti-pattern 1).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Urban flag → 0/1 | `if (is_urban) U=1.0 else U=0.0` scalar branch | `merge(1.0_wp, 0.0_wp, is_urban)` | Elemental, branchless, one line. |
| Grid broadcast | Manual nested loops applying the kernel | `elemental` function over component arrays (`g%cells%t_air`) OR the existing per-cell loop in `main.f90` | Idiomatic; Phase-2 driver loop already exists, reuse it. |
| Min/floor | Custom comparison | intrinsic `max(HI, t_air)` (elemental) | D-09 is literally one intrinsic call. |
| Test scaffolding | New assert framework | test-drive `new_unittest`/`check` (already wired) | Mirror `test/test_io.f90` exactly. |

**Key insight:** Phase 2 is ~80 lines of arithmetic across three tiny modules plus tests. The
only real risks are numeric (literal suffixing, °C/°F discipline, the boundary check) and test
design — not architecture.

## Runtime State Inventory

Not applicable — this is a greenfield feature phase (adds new modules + one config field), not a
rename/refactor/migration. One small note for the planner: adding the `d0` field to `coeffs_t`
and the `/coeffs/` namelist is a **schema addition**, not a migration. Existing namelist files
(including `test/fixtures/coeffs.nml`, `test/fixtures/coeffs_partial.nml`, and `data/coeffs.nml`)
that omit `d0` will still load because the default is set before `read` — but `data/coeffs.nml`
**should** be updated to include `d0 = 2.5` so the value is visible/tunable to the learner
(GRID-04 intent). No stored data, services, OS state, secrets, or build artifacts carry old
values — verified by reading all source/data/test files this session.

## Common Pitfalls

### Pitfall 1: The 80 °F boundary is checked on the simple-averaged value, not the raw inputs (B1)
**What goes wrong:** Implementers branch on `t_air >= 80°F` or on the raw Rothfusz output, producing
a discontinuity, or apply Rothfusz below its valid envelope and get feels-like *below* air temp.
**Why it happens:** The NWS algorithm's branch condition is subtle — it is computed on the
**simple Steadman formula already averaged with T**.
**Correct algorithm (verified numerically this session):**
1. `HI = 0.5_wp*(T + 61.0_wp + (T-68.0_wp)*1.2_wp + RH*0.094_wp)`  (T in °F)
2. `HI = (HI + T)/2.0_wp`  (average with temperature)
3. **If `HI >= 80.0_wp`**: replace `HI` with the full Rothfusz regression, then
   - if `RH < 13` and `80 <= T <= 112`: subtract `((13-RH)/4)*sqrt((17-abs(T-95))/17)`
   - if `RH > 85` and `80 <= T <= 87`: add `((RH-85)/10)*((87-T)/5)`
4. Otherwise keep the step-2 Steadman value.
**Boundary behavior (this matters for the HEAT-02 boundary test):** At `T = 80 °F, RH = 40 %`,
the step-2 averaged value is **79.79 °F**, which is **< 80**, so the algorithm stays on the
Steadman branch and returns 79.79 °F — even though the *published rounded table* shows 80. The
branch flips to Rothfusz around `T ≈ 80.2 °F` at RH 40 % (simple-avg scan this session:
T=80→79.79, T=81→80.84). **Write the boundary test against the algorithm's computed value, not
the rounded table cell.** Continuity is preserved because both branches are close near 80.
**How to avoid:** Implement the exact 4-step order above; test the just-below point (79 °F/70 %
→ 79.445 °F, Steadman) and a clearly-above point (90 °F/70 % → 105.92 °F, Rothfusz).
**Warning signs:** feels-like below air temp on a humid night cell; a kink at the boundary.

### Pitfall 2: Single-precision literals in Rothfusz (A1)
**What goes wrong:** `2.04901523` without `_wp` is single precision; the large opposing terms in
Rothfusz make the rounding visible (feels-like off by tenths, non-reproducible across `-O0`/`-O2`).
**How to avoid:** Suffix **every** literal `_wp`, including the regression coefficients and the
conversion constants (`9.0_wp/5.0_wp`, `32.0_wp`). Store the nine Rothfusz coefficients as named
`real(wp), parameter` constants in `constants_mod` for readability and to guarantee the kind.
**Warning signs:** Output changes between optimization levels; `-finit-real=snan` or a `-O0` vs
`-O2` diff reveals drift.

### Pitfall 3: Integer division / logical misuse in the budget (A2)
**What goes wrong:** `water_km/d0` is fine (both real), but forgetting `merge` for `is_urban`, or
any stray integer literal, zeroes a term.
**How to avoid:** All drivers are already `real(wp)` on `type(cell)` `[VERIFIED: src/grid.f90]`;
only `is_urban` needs `merge(1.0_wp, 0.0_wp, is_urban)`. `d0` must be `real(wp)` and `> 0`.

### Pitfall 4: Consuming Phase-3 coefficients (D-06)
**What goes wrong:** Multiplying ΔT by `m_predawn` etc. in Phase 2.
**How to avoid:** Phase 2 uses `m = 1` implicitly — simply do not reference any `m_*` field. The
fields exist on `coeffs_t` but stay dormant.

### Pitfall 5: Naming — air vs surface vs feels-like (B6)
**What goes wrong:** A generic `temp` variable doing double duty.
**How to avoid:** Use `t_air` (already on `cell`), `t_adj`/`t_base` for the offset-adjusted input,
and `feels_like` for the output. This is air-temperature → apparent-temperature, never surface temp.

## Code Examples

> All examples are illustrative skeletons grounded in the existing module style
> (`src/grid.f90`, `src/io.f90`) read this session, and the NWS algorithm verified numerically
> this session. Literals shown abbreviated; the planner must require `_wp` on every literal.

### °C↔°F helpers (add to `constants_mod`, elemental pure)
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

### Heat Index — `heat_index_mod` (elemental pure, °F in / °F out)
```fortran
! Source: NWS/WPC Heat Index Equation (Rothfusz + Steadman + adjustments),
!         algorithm order verified numerically this session.
elemental pure function heat_index_f(t_f, rh) result(hi)
    real(wp), intent(in) :: t_f, rh        ! T in °F, RH in %
    real(wp) :: hi
    hi = 0.5_wp*(t_f + 61.0_wp + (t_f - 68.0_wp)*1.2_wp + rh*0.094_wp)
    hi = (hi + t_f)/2.0_wp                  ! Steadman, averaged with T
    if (hi >= 80.0_wp) then
        hi = -42.379_wp + 2.04901523_wp*t_f + 10.14333127_wp*rh        &
             - 0.22475541_wp*t_f*rh - 0.00683783_wp*t_f*t_f            &
             - 0.05481717_wp*rh*rh + 0.00122874_wp*t_f*t_f*rh          &
             + 0.00085282_wp*t_f*rh*rh - 0.00000199_wp*t_f*t_f*rh*rh
        if (rh < 13.0_wp .and. t_f >= 80.0_wp .and. t_f <= 112.0_wp) then
            hi = hi - ((13.0_wp - rh)/4.0_wp)*sqrt((17.0_wp - abs(t_f - 95.0_wp))/17.0_wp)
        end if
        if (rh > 85.0_wp .and. t_f >= 80.0_wp .and. t_f <= 87.0_wp) then
            hi = hi + ((rh - 85.0_wp)/10.0_wp)*((87.0_wp - t_f)/5.0_wp)
        end if
    end if
end function heat_index_f
```

### UHI offset — `uhi_mod` (elemental pure, returns ΔT in °C)
```fortran
! Source: FEATURES.md §2 additive model; D-03/D-04 locked.
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

### Feels-like wrapper — `feels_mod` (elemental pure, °C in / °C out; D-01,D-03,D-08,D-09)
```fortran
elemental pure function feels_like_c(t_base, rh, building, tree, water_km, is_urban, &
                                     w_build, w_urban, w_tree, w_water, d0) result(feels_c)
    real(wp), intent(in) :: t_base, rh, building, tree, water_km
    logical,  intent(in) :: is_urban
    real(wp), intent(in) :: w_build, w_urban, w_tree, w_water, d0
    real(wp) :: feels_c, t_adj_c, hi_f
    t_adj_c = t_base + uhi_offset(building, tree, water_km, is_urban, &
                                  w_build, w_urban, w_tree, w_water, d0)
    hi_f    = heat_index_f(c_to_f(t_adj_c), rh)
    feels_c = max(f_to_c(hi_f), t_adj_c)     ! floor (D-09): never below the air input
end function feels_like_c
```
> Note on the floor (D-09): floor against `t_adj_c` (the offset-adjusted air temp fed to the
> heat index) so HEAT-02 holds for the value actually computed. (PITFALLS B1 phrases it as "below
> air temperature"; here the air input to the index is `t_adj_c`.) The planner should confirm
> which reference the floor uses — recommend `t_adj_c` for internal consistency with D-01.

### Adding `d0` to the namelist (precise edits)
**In `src/grid.f90`, `type, public :: coeffs_t`** — add one field:
```fortran
real(wp) :: d0
```
**In `src/io.f90`, `read_coeffs_nml`** — three edits mirroring the existing pattern
`[VERIFIED: src/io.f90 lines 19-71]`:
```fortran
real(wp) :: d0                                  ! 1. declare local (with the other reals)
namelist /coeffs/ ..., t_base, rh_base, d0, nx, ny   ! 2. add to the group
d0 = 2.5_wp                                     ! 3a. set default BEFORE open/read
...
c%d0 = d0                                        ! 3b. copy into coeffs_t after read
```
**In `data/coeffs.nml`** — add `d0 = 2.5` (e.g. after `rh_base = 78.0`).

### Wiring into `app/main.f90` (extend the existing District List loop)
The driver already loops occupied cells and prints a per-cell line
`[VERIFIED: app/main.f90 lines 34-47]`. Add `use feels_mod, only: feels_like_c` and append the
computed value to that line, e.g.:
```fortran
real(wp) :: feels
...
feels = feels_like_c(coeffs%t_base, c%rh, c%building, c%tree, c%water_km, c%is_urban, &
                     coeffs%w_build, coeffs%w_urban, coeffs%w_tree, coeffs%w_water, coeffs%d0)
! extend the existing write(...) with: ', FEELS=', feels
```
Do **not** add a `feels_like` component to `type(cell)` (see Anti-Patterns / Pattern 3).

### test-drive suite skeleton (mirror `test/test_io.f90` exactly)
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
    subroutine collect(testsuite)
        type(unittest_type), allocatable, intent(out) :: testsuite(:)
        allocate(testsuite(2))
        testsuite(1) = new_unittest('ref_values', test_ref)
        testsuite(2) = new_unittest('boundary',   test_boundary)
    end subroutine collect
    subroutine test_ref(error)
        type(error_type), allocatable, intent(out) :: error
        call check(error, abs(heat_index_f(90.0_wp, 70.0_wp) - 105.9220_wp) < 1.0e-2_wp)
        if (allocated(error)) return
        call check(error, abs(heat_index_f(86.0_wp, 90.0_wp) - 105.3944_wp) < 1.0e-2_wp) ! RH>85 adj
    end subroutine test_ref
    subroutine test_boundary(error)
        type(error_type), allocatable, intent(out) :: error
        call check(error, abs(heat_index_f(79.0_wp, 70.0_wp) - 79.4450_wp) < 1.0e-2_wp) ! Steadman
    end subroutine test_boundary
end program test_heat_index
```
Note: the partial-suite registration in `test/test_io.f90` runs only `testsuites(1)`; follow the
same single-suite-per-program form for each new test program.

## NWS Heat-Index Reference Values (for exact assert targets)

Computed this session with the canonical NWS algorithm (full Rothfusz + adjustments, °F internal).
Use a tolerance of **±0.01 °F** (or convert and use ±0.01 °C); these are exact to 4 decimals.
`[VERIFIED: recomputed numerically this session from the NWS algorithm]` / `[CITED:
wpc.ncep.noaa.gov/html/heatindex_equation.shtml]`

| Case | T (°F) | RH (%) | HI (°F) | HI (°C) | Branch | Exercises |
|------|-------:|-------:|--------:|--------:|--------|-----------|
| Just-below boundary | 79.000 | 70 | 79.4450 | 26.3583 | Steadman | continuity below 80 |
| Cool/humid night | 75.000 | 80 | 75.4800 | 24.1556 | Steadman | low-end, near floor |
| At nominal 80°F corner | 80.000 | 40 | 79.7900 | 26.5500 | Steadman | algorithm < 80 ≠ rounded table 80 |
| Mid Rothfusz | 90.000 | 40 | 90.6797 | 32.5998 | Rothfusz | core regression |
| Humid Rothfusz | 90.000 | 70 | 105.9220 | 41.0678 | Rothfusz | high-RH, no adj (T>87) |
| **RH>85 adjustment** | 86.000 | 90 | 105.3944 | 40.7746 | Rothfusz + humid adj | the HCMC-relevant add (D-07) |
| Hot dry | 100.000 | 40 | 109.2556 | 42.9198 | Rothfusz | upper range |
| HCMC D1 base (33 °C) | 91.400 | 75 | 114.2903 | 45.7168 | Rothfusz | realistic seed point |
| HCMC Can Gio (29 °C) | 84.200 | 88 | 98.0177 | 36.6765 | Rothfusz + humid adj | coastal, adj active |

**Recommended minimal assert set for the planner** (covers HEAT-01 + HEAT-02):
1. `90 °F / 70 %` → `105.9220` (core Rothfusz)
2. `86 °F / 90 %` → `105.3944` (RH>85 % adjustment path — D-07)
3. `79 °F / 70 %` → `79.4450` (just-below-boundary Steadman branch)
4. `75 °F / 80 %` → `75.4800` (cool branch; confirm feels-like ≥ air after floor)

## Ordering Verification (UHI-02, full pipeline against the real seed)

Computed this session with `feels_like_c` over the actual `data/hcmc_districts.csv` rows
(`t_base=28 °C`, `d0=2.5`, locked weights), confirming the headline ordering holds **even with
per-cell RH varying** (point #7). `[VERIFIED: recomputed numerically this session]`

| Rank | Cell | ΔT (°C) | t_adj (°C) | RH (%) | feels (°C) |
|-----:|------|--------:|-----------:|-------:|-----------:|
| 1 | Binh Tan Industrial | +3.478 | 31.478 | 72 | 39.586 |
| 2 | Thu Duc Industrial | +3.281 | 31.281 | 72 | 39.013 |
| 3 | District 1 | +1.959 | 29.959 | 75 | 36.189 |
| 4 | District 7 | +0.723 | 28.723 | 80 | 33.980 |
| 5 | Cu Chi Rural Fringe | −0.980 | 27.020 | 82 | 29.978 |
| 6 | Tao Dan Park | −1.248 | 26.752 | 80 | 29.200 |
| 7 | Nha Be Peri-urban | −1.862 | 26.138 | 83 | 26.556 |
| 8 | Can Gio | −3.821 | 24.179 | 88 | 24.564 |

**Headline check satisfied:** all dense-treeless urban cells (industrial, D1, D7) outrank all
green/waterfront/rural cells (park, Can Gio, rural). Note: rural-fringe (rank 5) edges out the
urban park (rank 6) — this is *not* a violation of UHI-02 (which compares dense-urban vs
green/water/rural), and D-10 controls archetype values inside the test anyway, so the test does
not depend on this seed-data quirk.

## Numeric Gotchas / Budget Magnitude (point #7)

With locked weights `w_build=3.0, w_urban=1.0, w_tree=2.5, w_water=2.0` and drivers in [0,1]/{0,1},
`Wprox ∈ (0,1]`:
- **Max (hottest):** `B=1, U=1, V=0, Wprox→0` (far from water) → `ΔT = +4.0 °C`
- **Min (coolest):** `B=0, U=0, V=1, Wprox=1` (at water) → `ΔT = −4.5 °C`
- Range ≈ **−4.5 … +4.0 °C** — each driver single-digit °C, satisfying UHI-01. `[VERIFIED:
  recomputed this session]`

**How per-cell RH keeps waterfront cooler despite varying humidity:** waterfront/green cells carry
the most negative ΔT (Can Gio −3.82, park −1.25), so their heat-index *temperature input* is
several °C lower. Although their RH is higher (88 % vs 72 %), which raises the heat index, the
~7 °C spread in `t_adj` dominates the heat-index response — the final feels-like still ranks them
coolest (table above). The RH>85 % adjustment (active for Can Gio, Nha Be) nudges them up slightly
but not enough to invert the ordering. This is exactly why D-02 keeps water acting on temperature
only (no water→RH coupling) — adding RH coupling would risk the B3 double-count that could flip a
waterfront cell hotter.

**Floor edge case worth a test:** for a cool/dry synthetic cell the Steadman branch can return
below the air input (e.g. `75 °F / 20 %` → 74.07 °F < 75), so `max(HI, t_adj)` is load-bearing —
include one such case in `test_heat_index` to lock HEAT-02 for the cold/dry corner (D-10 archetype
cells can be dry).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Simple near/far water term | Continuous `exp(−d/d0)` decay (D-04) | Phase-2 decision | REFN-02 pulled into v1; smoother spatial gradient. Update REQUIREMENTS.md to move REFN-02 out of v2 on next pass. |
| Rothfusz applied unconditionally | Two-branch Steadman↔Rothfusz + adjustments | Locked (D-07) | Correct night-cell behavior; the headline science guard (B1). |

**Deprecated/outdated:** none for this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `merge(1.0_wp, 0.0_wp, is_urban)` is the cleanest logical→real conversion for the urban term | Patterns / UHI example | Low — standard intrinsic, elemental; alternative is an explicit `if`. |
| A2 | Floor (D-09) is best applied against `t_adj_c` (offset-adjusted input), not the original `cell%t_air` | Feels-like wrapper | Medium — if the planner/user intends the floor vs the *original* `t_air`, the wrapper changes. Flag for confirmation; D-01 uses `t_base` not `cell%t_air` as the temperature source, so `t_adj_c` is the consistent reference. |
| A3 | `d0 = 2.5` km is a sensible default within the D-05 ~2–3 km discretion band | d0 namelist edit | Low — explicitly Claude's discretion; tunable without recompile. |
| A4 | The NWS published-table value (80 at 80°F/40%) differing from the algorithm's 79.79 is acceptable for the boundary test | Pitfall 1 / Reference Values | Low — standard NWS algorithm behavior; documented so the test asserts the computed value. |

## Open Questions (RESOLVED)

1. **Should the console output be extended in place or get a new summary line?**
   - What we know: D (discretion) leaves console surfacing to planning; OUT-02 (full summary:
     hottest/coolest/avg/gap) is **Phase 4**, not Phase 2.
   - What's unclear: whether Phase 2 should print just per-cell `FEELS=` on the existing line, or
     also a minimal hottest/coolest hint.
   - Recommendation: Phase 2 — append `FEELS=` to the existing per-cell District List line only;
     leave the aggregate summary to Phase 4 (OUT-02) to avoid scope creep.
   - **RESOLVED:** Adopted in plan 02-03 Task 2 — `FEELS=` appended to the existing per-cell line
     only; aggregate summary deferred to Phase 4 (OUT-02).

2. **One `feels_mod` wrapper vs computing inline in the driver?**
   - What we know: kernels must be reusable for Phase 3 (multi-timestep) and Phase 4 (CSV).
   - Recommendation: create the thin `feels_mod` wrapper (Pattern 3) so Phase 3/4 call one named
     function; the driver calls it once per cell. Keeps the formula in a single tested place.
   - **RESOLVED:** Adopted in plan 02-03 Task 1 — thin `feels_mod` wrapper (`feels_like_c`) created;
     driver calls it once per cell; Phase 3/4 reuse the same named function.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gfortran | compile all modules | ✓ | GCC 16.1.0 | — |
| fpm | build/test/run | ✓ | 0.13.0 | — |
| test-drive | new test suites | ✓ (vendored via fpm.toml) | v0.6.0 | hand-rolled assert (not needed) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — full toolchain present and verified this session.

### Build/test flag note (LOCKED memory fact — surface to planner)

`fpm` 0.13.0 **rejects `[profiles.*.gfortran]` manifest profiles** (per project MEMORY.md). The
strict dev flags from STACK.md must be passed on the command line, **not** added to `fpm.toml`:

```bash
fpm test --flag "-std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -finit-real=snan"
fpm run  --flag "-std=f2018 -fimplicit-none -Wall -Wextra -fcheck=all -finit-real=snan"
```

`-finit-real=snan` + `-ffpe-trap=invalid` will surface any uninitialized read or NaN from a bad
heat-index branch at the source — strongly recommended while building the kernels. Release runs
use `-O2 -std=f2018 -fimplicit-none -Wall`.

## Security Domain

`security_enforcement` is enabled (ASVS level 1) in config. This phase is a **local, single-user
scientific CLI** with no network, no authentication, no session/access control, and no new
untrusted-input surface — it reads two local, already-validated project data files (the Phase-1
loader performs fail-loud range validation `[VERIFIED: src/io.f90]`).

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — no auth surface |
| V3 Session Management | no | n/a — batch CLI |
| V4 Access Control | no | n/a — local single-user |
| V5 Input Validation | partial | New numeric input `d0` from `coeffs.nml`: should be validated `> 0` (division `water_km/d0`); the planner should add a guard or document the namelist contract. RH/temp/density already validated in Phase 1. |
| V6 Cryptography | no | n/a — no secrets/crypto |

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `d0 <= 0` in namelist → divide-by-zero / Inf in `exp(-water_km/d0)` | Denial of Service (local, self-inflicted) | Validate `d0 > 0` at load (extend `read_coeffs_nml` validation) or document the contract; `-ffpe-trap=zero` will catch it at dev time. |
| Malformed numeric in `coeffs.nml` | Tampering (local) | Existing namelist `iostat`/`iomsg` handling returns a nonzero stat `[VERIFIED: src/io.f90]`. |

**Recommendation:** add a single `d0 > 0` validity check (single-digit lines) to `read_coeffs_nml`
to keep the fail-loud Phase-1 convention; otherwise no security work is warranted for this phase.

## Sources

### Primary (HIGH confidence)
- NWS/WPC — The Heat Index Equation (Rothfusz regression, Steadman simple formula, RH<13 %/RH>85 %
  adjustments, valid-range note). `[CITED: wpc.ncep.noaa.gov/html/heatindex_equation.shtml]`
- NWS/WPC — Heat Index Equation body (valid range T ≥ 80 °F, RH ≥ 40 %).
  `[CITED: wpc.ncep.noaa.gov/html/heatindex_equationbody.html]`
- Existing project source read this session: `src/kinds.f90`, `src/constants.f90`, `src/grid.f90`,
  `src/io.f90`, `app/main.f90`, `test/test_io.f90`, `test/test_e2e_load.f90`, `data/coeffs.nml`,
  `data/hcmc_districts.csv`, `fpm.toml` `[VERIFIED: read this session]`.
- `.planning/research/FEATURES.md`, `PITFALLS.md`, `STACK.md`, `ARCHITECTURE.md` (project research,
  HIGH-confidence science + tooling) `[VERIFIED: read this session]`.
- Heat-index reference values + full-pipeline ordering recomputed numerically this session
  `[VERIFIED: numeric recomputation from the NWS algorithm]`.

### Secondary (MEDIUM confidence)
- FEATURES.md §2 UHI additive model / HCMC archetypes (illustrative weights, MEDIUM by design).

### Tertiary (LOW confidence)
- none.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; toolchain versions verified this session.
- Heat-index algorithm & reference values: HIGH — algorithm from authoritative NWS source and
  recomputed numerically; boundary behavior characterized exactly.
- UHI budget & ordering: HIGH for the math (recomputed against real seed); MEDIUM for the
  *weights* themselves (illustrative, locked by D-03, calibration deferred to Phase 3).
- Fortran patterns: HIGH — mirror existing Phase-1 modules verified by reading the source.

**Research date:** 2026-06-28
**Valid until:** ~2026-07-28 (stable; NWS formula and Fortran semantics are non-volatile — the
only refresh trigger is a gfortran/fpm/test-drive major version bump).
