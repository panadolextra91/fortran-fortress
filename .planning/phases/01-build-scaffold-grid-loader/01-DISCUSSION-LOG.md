# Phase 1: Build Scaffold & Grid Loader - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 1-Build Scaffold & Grid Loader
**Areas discussed:** Data file format, Grid geometry, Seed data scope, Error handling

---

## Data File Format

| Option | Description | Selected |
|--------|-------------|----------|
| CSV grid + namelist coefficients | District table as CSV (Excel-friendly); model coefficients as Fortran namelist | ✓ |
| All CSV | Both grid and coefficients in CSV — one format, but scalar coefficients feel forced | |
| All namelist | Both in Fortran namelist — native, no parser, but the grid table reads awkwardly in Excel | |

**User's choice:** CSV grid + namelist coefficients (recommended)
**Notes:** User wants to edit the grid in Excel; coefficients are scalars that suit namelist.

---

## Grid Geometry

| Option | Description | Selected |
|--------|-------------|----------|
| District + (i,j) coordinates | One row per district with explicit (i,j) placing it on a 2D map raster | ✓ |
| Pure NxM raster | Full square grid, each cell assigned nearest-region params — finer but many empty/interpolated cells | |
| Pure district list (1D) | Districts without coordinates — simplest, but "map" becomes a ranking with no spatial layout | |

**User's choice:** District + (i,j) coordinates (recommended)
**Notes:** Real 2D heat map while staying relatable by district name. Sparse/empty cells acceptable.

---

## Seed Data Scope

| Option | Description | Selected |
|--------|-------------|----------|
| ~12–16 real districts | Rich map covering all 5 archetypes + familiar districts (Q1,3,5,7,10, Binh Thanh, Thu Duc, Tan Binh, Go Vap, Can Gio...) | ✓ |
| 5 archetypes | Exactly the research archetypes: D1 core, industrial, park, Can Gio, rural — minimal, sparse map | |

**User's choice:** ~12–16 real districts (recommended)
**Notes:** More data entry accepted in exchange for a richer, more recognizable map.

---

## Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Stop + report line number | Loud failure with line number and reason; prevents silent column-shift bugs (research-backed) | ✓ |
| Skip + warn | Drop bad rows, print warning, continue — convenient but can silently drop cells | |
| Clamp + warn | Clamp out-of-range values into valid range + warn — always runs but hides bad data | |

**User's choice:** Stop + report line number (recommended)
**Notes:** Deliberate teaching/debugging aid; validation runs at load time before any physics.

---

## Claude's Discretion

- Exact CSV column order and header names.
- Precise (i,j) coordinates per district.
- Namelist group/variable names and internal derived-type field names.
- Strict dev gfortran flag profile details (within STACK.md guidance).

## Deferred Ideas

- Rendering of empty grid cells → Phase 4 (output).
- Humidex toggle, continuous water decay, smooth cosine diurnal, more districts, seasonal runs → v2 (REFN-01..05).
- Tuning UHI weights to a 3–8 °C night gap → Phase 2/3 calibration (Phase 1 only loads the weights).
