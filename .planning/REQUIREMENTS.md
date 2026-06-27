# Requirements: Fortran Fortress — HCMC Urban Heat Island Simulator

**Defined:** 2026-06-28
**Core Value:** The simulated heat map must be scientifically believable — dense, treeless
urban cells come out hotter than green/waterfront/rural cells, and the night-time
urban–rural gap persists/grows — for the same baseline weather.

## v1 Requirements

Requirements for the initial release. Each maps to roadmap phases.

### Grid & Data

- [ ] **GRID-01**: The simulator loads a 2D grid of city cells from an editable data file
      (changing the city data requires no recompile).
- [ ] **GRID-02**: Each cell carries air temperature, relative humidity, distance to
      river/ocean, building density, tree density, and an urban/rural classification.
- [ ] **GRID-03**: The seed data file ships with realistic-ish Ho Chi Minh City district
      archetypes (e.g. District 1 core, industrial zone, park/green cell, Can Gio coast,
      rural fringe).
- [ ] **GRID-04**: All model coefficients/weights (UHI weights, diurnal multipliers) live
      in the config/data file and can be edited without recompiling.

### Feels-like Temperature

- [ ] **HEAT-01**: The simulator computes a per-cell feels-like (apparent) temperature from
      air temperature and relative humidity.
- [ ] **HEAT-02**: The heat-index calculation guards its valid range — using the simple
      Steadman average below ~26.7 °C (80 °F) and the Rothfusz regression at/above it — so
      cool night cells never produce nonsense (feels-like below air temp).

### Urban Heat Island Offset

- [ ] **UHI-01**: The simulator applies an additive UHI temperature offset where higher
      building density and urban class raise feels-like, while higher tree density and
      water proximity lower it.
- [ ] **UHI-02**: For the same baseline weather, dense treeless urban cells rank hotter than
      green / waterfront / rural cells (monotonic ordering — the headline correctness check,
      verified by an automated test).

### Day–Night Cycle

- [ ] **TIME-01**: The simulator evaluates the grid at multiple times of day (e.g. morning,
      mid-afternoon peak, evening, pre-dawn night).
- [ ] **TIME-02**: The urban–rural temperature gap is larger at night than at mid-afternoon
      (night-amplified UHI), verified by an automated `gap_night > gap_afternoon` check.

### Scenario Comparison

- [ ] **SCEN-01**: The simulator runs a baseline plus alternative what-if scenarios (at least
      one "add trees" and one "more concrete") without mutating the baseline grid.
- [ ] **SCEN-02**: For each scenario the simulator reports the per-cell and city-average
      temperature change versus baseline.

### Output

- [ ] **OUT-01**: The simulator exports results to CSV with one row per cell × timestep ×
      scenario and a deterministic column order (grid indices, time label, scenario label,
      air temp, feels-like, UHI offset).
- [ ] **OUT-02**: When run, the simulator prints a console summary: hottest and coolest
      cells, city-average feels-like, and the urban–rural gap (per timestep).

## v2 Requirements

Deferred to a future release. Tracked but not in the current roadmap.

### Model Refinements

- **REFN-01**: Humidex as an alternative feels-like index, selectable via config toggle.
- **REFN-02**: Continuous distance-to-water cooling decay (vs. a simple near/far term).
- **REFN-03**: Smooth cosine diurnal curve replacing the time-of-day lookup table.
- **REFN-04**: More districts / finer archetypes once the 5-archetype set is validated.
- **REFN-05**: Seasonal runs (dry-season vs. wet-season baselines).

## Out of Scope

Explicitly excluded (anti-features from research). Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Full CFD / 3D atmospheric & fluid dynamics | Months of work, numerically unstable, opaque — contradicts the illustrative/transparent goal. Use the parametric additive offset model. |
| Weather forecasting / predictive meteorology | Requires data assimilation & NWP; the model illustrates *structure*, not future state. Scenario comparison answers "what if". |
| Live / real-time weather API ingestion | Network dependency & schema churn break the self-contained learning tool. Use a static seed file. |
| Per-building / sub-district resolution | Data unavailable; implies forecasting precision the model can't deliver. Cells are district-scale. |
| GUI / web front-end / built-in plotting | Pulls Fortran toward UI it's bad at. CSV → Excel/Python/gnuplot is the contract. |
| Wind & rain advection fields | Needs vector fields and advection numerics. Sea-breeze approximated via the water-proximity term; real wind is a future milestone. |
| Precise calibration to measured station data | Implies predictive accuracy the model disclaims. Calibrate qualitatively (ranking + 3–8 °C night gap). |

## Traceability

Which phases cover which requirements. **Populated during roadmap creation.**

| Requirement | Phase | Status |
|-------------|-------|--------|
| GRID-01 | Phase 1 | Pending |
| GRID-02 | Phase 1 | Pending |
| GRID-03 | Phase 1 | Pending |
| GRID-04 | Phase 1 | Pending |
| HEAT-01 | Phase 2 | Pending |
| HEAT-02 | Phase 2 | Pending |
| UHI-01 | Phase 2 | Pending |
| UHI-02 | Phase 2 | Pending |
| TIME-01 | Phase 3 | Pending |
| TIME-02 | Phase 3 | Pending |
| SCEN-01 | Phase 3 | Pending |
| SCEN-02 | Phase 3 | Pending |
| OUT-01 | Phase 4 | Pending |
| OUT-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0

---
*Requirements defined: 2026-06-28*
*Last updated: 2026-06-28 after roadmap creation (traceability populated)*
