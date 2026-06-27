# Fortran Fortress — Ho Chi Minh City Urban Heat Island Simulator

## What This Is

A scientific-computing program written in modern Fortran that simulates the **urban
heat island (UHI) effect** across Ho Chi Minh City on a 2D grid. Each grid cell
represents a district/area with realistic-ish parameters (air temperature, humidity,
distance to river/ocean, building density, tree density, urban vs. rural). The program
computes a **feels-like (apparent) temperature** per cell, models a **day–night cycle**,
and exports the results as **CSV** for external plotting. It is built to *illustrate the
science* of why the urban core runs hotter than green/waterfront areas — for a learner
demonstrating numerical computing in Fortran.

## Core Value

The simulated heat map must be **scientifically believable**: dense, treeless urban cells
must come out hotter than green / waterfront / rural cells — and the night-time UHI gap
must persist — for the same baseline weather. If the spatial pattern is wrong, nothing
else matters.

## Requirements

### Validated

(None yet — ship to validate)

### Active

<!-- All hypotheses until shipped and validated. -->

- [ ] Represent HCMC as a 2D grid of cells, each carrying: air temperature, relative
      humidity, distance to river/ocean, building density, tree density, and an
      urban/rural classification.
- [ ] Seed the grid from realistic-ish Ho Chi Minh City district data (e.g. District 1,
      Thu Duc, Can Gio, etc.) loaded from a data file rather than hard-coded constants.
- [ ] Compute a per-cell **heat index / apparent temperature** from air temperature and
      humidity using an established formula.
- [ ] Apply an **urban-heat-island adjustment** per cell: higher building density and
      lower tree density raise the feels-like temperature; proximity to water and higher
      tree density lower it.
- [ ] Model a **day–night cycle** by evaluating the grid at several times of day (e.g.
      morning / mid-afternoon peak / night) and reproduce the known result that the
      urban–rural temperature gap is largest at night.
- [ ] Support **what-if scenario comparison**: run the same grid under a baseline plus
      alternative scenarios (e.g. "add trees", "more concrete") and quantify the cooling
      or warming each scenario produces.
- [ ] Export results to **CSV** (one row per cell per timestep/scenario) suitable for
      plotting in Excel / Python / gnuplot.
- [ ] Print a short **terminal summary** when the program runs: hottest and coolest cells,
      city-average feels-like temperature, and the urban–rural gap.

### Out of Scope

- Live/real-time weather data or web API integration — this is a self-contained
  illustrative model, not a data pipeline.
- Weather *forecasting* / predictive meteorology — the model illustrates UHI structure,
  it does not predict future weather.
- GUI, web front-end, or built-in plotting — output is CSV for external tools; keeps the
  Fortran core focused.
- Full atmospheric/fluid dynamics, 3D physics, wind and rain fields — the model is a
  simplified 2D parametric one. (Wind/rain could be a future milestone.)
- Sub-district / per-building resolution — grid cells are district-scale.

## Context

- **Greenfield** project. The repository currently contains only a throwaway "Hello
  World" Fortran scientific-computing scaffold (`src/numerics.f90`, `src/main.f90`,
  `Makefile`) built earlier in the session to confirm the toolchain works. The simulator
  is a fresh build; the scaffold may be reused, replaced, or removed.
- Toolchain is already set up and verified: `gfortran` (Homebrew GCC 16.1.0), GNU `make`,
  and `cmake` available on macOS (Apple Silicon). VS Code with the Modern Fortran
  extension recommended (`.vscode/extensions.json` already present).
- Domain is the **urban heat island effect** — the well-documented phenomenon where dense
  built-up areas are hotter than surrounding vegetated/rural land, especially at night.
  The user's stated drivers (heat, humidity, distance to water, building density, tree
  density, urban/rural) map directly onto standard UHI parameterizations.
- Primary purpose is **scientific illustration / learning**, so model transparency and
  correctness of the spatial pattern matter more than predictive accuracy.

## Constraints

- **Tech stack**: Modern Fortran (free-form, `implicit none`, `real64` kinds), compiled
  with `gfortran` and built with **fpm** (Fortran Package Manager). — User's chosen
  language for a scientific-computing project; fpm chosen over a plain Makefile for
  automatic module compile-order resolution and built-in `fpm run`/`fpm test`.
- **Output format**: CSV files (plus a brief console summary). — User wants to plot
  results in external tools; no built-in graphics.
- **Data**: Realistic-ish HCMC district parameters loaded from a data/config file. —
  Keeps the model relatable and lets scenarios be edited without recompiling.
- **Model fidelity**: Illustrative, not predictive. — Simplicity and correct qualitative
  behavior take priority over meteorological precision.
- **Platform**: macOS / Apple Silicon, terminal + VS Code.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 2D grid heat-map (vs. point calculator or pure time-series) | Best shows the *spatial* UHI pattern across the city | — Pending |
| Real-ish HCMC district data (vs. synthetic/random grid) | Relatable, easier to sanity-check, more compelling demo | — Pending |
| Day–night cycle (vs. single snapshot) | Night-time UHI gap is the signature scientific result worth showing | — Pending |
| What-if scenario comparison included in v1 | Quantifying "more trees → how much cooler" is the key illustrative payoff | — Pending |
| CSV output (vs. ASCII map / image) | Lets user plot nicely in external tools; keeps Fortran core simple | — Pending |
| Heat index + UHI offset model | Standard, transparent parameterization matching the user's input factors | — Pending |
| Build with fpm (vs plain Makefile) | fpm auto-resolves Fortran module compile order (the #1 hand-written-Makefile pain) and gives `fpm run`/`fpm test` for free; research-recommended | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-28 after initialization*
