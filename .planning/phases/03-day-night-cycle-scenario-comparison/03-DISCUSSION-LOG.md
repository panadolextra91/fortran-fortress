# Phase 3: Day-Night Cycle & Scenario Comparison - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29
**Phase:** 3-Day-Night Cycle & Scenario Comparison
**Areas discussed:** Diurnal mechanism, Scenario design, Gap metric & calibration, Phase 3 output surfacing

---

## Diurnal mechanism

### Q1 — How does time-of-day act on the physics?

| Option | Description | Selected |
|--------|-------------|----------|
| Base swing + m(t) on offset | Add a diurnal base-temp curve (afternoon ~33 °C hottest → pre-dawn ~24–26 °C cool) AND m(t) scales the UHI offset. Afternoon absolute-hottest; gap largest at night; night cells naturally near 80 °F to re-verify HEAT-02. Adds a per-time base set to config. | ✓ |
| m(t) on offset only (flat base) | Keep uniform t_base all day (Phase 2 D-01); only m(t) scales the offset. Simplest, reuses existing m_*, most "same baseline" honest. Downside: pre-dawn urban cells end up absolute-hotter than afternoon — counter-intuitive when plotted. | |

**User's choice:** Base swing + m(t) on offset
**Notes:** Pre-framed that base temp cancels in the urban–rural gap (uniform in space per time), so the base swing does not affect the `gap_night > gap_afternoon` test — it only sets absolute realism and exercises the HEAT-02 night guard.

### Q2 — How to represent the diurnal base temp + timestep set?

| Option | Description | Selected |
|--------|-------------|----------|
| Lookup table 4 timesteps in coeffs.nml | Add base_morning/afternoon/evening/predawn to coeffs.nml beside m_* (4 timesteps). Editable without recompile (GRID-04); simple; matches existing scaffold. REFN-03 cosine stays v2. | ✓ |
| t_base + amplitude | One mean t_base + an amplitude, derive each hour via a fixed shape factor. Fewer config numbers but less transparent for a learner. | |
| Smooth cosine (pull REFN-03 into v1) | Continuous cosine curve instead of a lookup. Prettier but REFN-03 is v2 — pulling it in expands scope. | |

**User's choice:** Lookup table 4 timesteps in coeffs.nml
**Notes:** Keeps the diurnal curve editable and learner-tunable; smooth cosine deferred to v2.

---

## Scenario design

### Q1 — Where are scenarios defined and how are delta magnitudes tuned?

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: structure in code + deltas in config | type(scenario_t) fixed in scenario_mod ("add trees", "more concrete"); delta magnitudes (add_trees_delta, concrete_delta) in coeffs.nml, tunable without recompile. Balances simplicity + tunability, matches how coeffs already work. | ✓ |
| Hardcode entirely in scenario_mod | type(scenario_t) + 2 prebuilt scenarios, fixed deltas in code. Simplest, minimal SCEN-01; changing intensity needs a recompile. | |
| Fully editable in data file | Scenario list (name + driver + delta) read from data/ like the grid. Most GRID-04-faithful but adds parsing code — overkill for 2 v1 scenarios. | |

**User's choice:** Hybrid: structure in code + deltas in config

### Q2 — Which cells do scenarios apply to, and how is the [0,1] boundary handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Whole grid + clamp [0,1] | "add trees" adds delta to tree on every cell; "more concrete" adds to building on every cell; clamp result to [0,1]. Simple, apples-to-apples (one global driver, B5). Already-green cells clamp → little change; low-tree urban core changes most. | ✓ |
| Urban/dense cells only | Intervene only on is_urban cells — more realistic "plant trees in the core" story, but delta becomes cell-dependent and more complex. | |

**User's choice:** Whole grid + clamp [0,1]
**Notes:** "more concrete" changes building only (not is_urban) to keep exactly one driver per scenario (PITFALLS B5).

---

## Gap metric & calibration

### Q1 — How is the urban–rural gap defined for the gap_night > gap_afternoon test?

| Option | Description | Selected |
|--------|-------------|----------|
| Mean(urban) − mean(rural) | Mean feels-like over is_urban cells minus mean over rural cells. Stable, outlier-resistant, classic canopy-layer UHI; reusable by the Phase 4 console summary. | ✓ |
| Max(urban) − min(rural) | Hottest cell minus coolest. Dramatic/large numbers but outlier-sensitive and seed-dependent. | |
| Hottest urban − rural reference cell | Compare hottest urban cell with a fixed rural reference cell. Intuitive but depends on the chosen reference. | |

**User's choice:** Mean(urban) − mean(rural)

### Q2 — How far does Phase 3 calibrate magnitude, and what do the tests lock?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard direction + soft magnitude check | HARD test for gap_night > gap_afternoon (+ night-sanity HEAT-02). Tune m_*/weights so peak night mean-gap lands ~3–8 °C, but magnitude is only a soft check (printed/warned, no build fail). Honors Phase 2 D-11 (test by rank/sign, not absolute °C). | ✓ |
| Direction-only | Only assert gap_night > gap_afternoon + night-sanity. Tune lightly for plausible magnitude but lock no number. Most robust; magnitude purely illustrative. | |
| Hard magnitude test ~3–8 °C | Fail build if peak night gap leaves ~3–8 °C. Strongest believability pressure but brittle — seed/weight edits can break it; conflicts with D-11. | |

**User's choice:** Hard direction + soft magnitude check
**Notes:** Ties to the STATE.md Phase-3 blocker (weights illustrative, not fitted). Tuning toward ~3–8 °C happens during execution; only the direction is build-gated.

---

## Phase 3 output surfacing

### Q1 — How does Phase 3 surface results on `fpm run`?

| Option | Description | Selected |
|--------|-------------|----------|
| Engine + test + minimal console | Build the diurnal + scenario engine + invariant tests; driver prints minimal evidence (one line/timestep mean-gap + one line/scenario city-average delta). Full report + CSV → Phase 4. Clean phase boundary, learner still sees evidence. | ✓ |
| Full table in Phase 3 | Print full per-timestep gap + per-cell/city-average scenario deltas now. Visible "done" but encroaches on Phase 4 (OUT-02) and may need refactor when Phase 4 adds CSV. | |
| Compute + test only, no output | Pure compute + asserts, main.f90 ~unchanged. Leanest but `fpm run` shows no diurnal/scenario evidence — only `fpm test` does. | |

**User's choice:** Engine + test + minimal console

---

## Claude's Discretion

- Module names/APIs (`diurnal_mod`, `scenario_mod`, `summary_mod` suggested).
- How `m(t)` and per-timestep `base(t)` thread into the feels pipeline / `feels_like_c` signature (kept elemental pure).
- Derived-type and field names; exact default `base_*` and delta values within FEATURES HCMC ranges.
- Exact in-test synthetic archetypes (reuse Phase 2's).
- Precise minimal console format.

## Deferred Ideas

- Smooth cosine diurnal curve (REFN-03) — v2.
- CSV export + full console summary (OUT-01/OUT-02) — Phase 4.
- Fully config-driven arbitrary scenario list — possible v2.
- Humidex toggle (REFN-01), more districts (REFN-04), seasonal baselines (REFN-05) — v2.
- Time-varying / per-scenario humidity — out of scope; rh stays per-cell static.
</content>
