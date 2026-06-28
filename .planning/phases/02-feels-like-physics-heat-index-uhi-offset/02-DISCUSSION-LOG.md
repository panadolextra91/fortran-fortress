# Phase 2: Feels-Like Physics (Heat Index + UHI Offset) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 2-Feels-Like Physics (Heat Index + UHI Offset)
**Areas discussed:** Baseline weather source, UHI offset structure, Heat-index algorithm, Ordering test design

---

## Baseline Weather Source

| Option | Description | Selected |
|--------|-------------|----------|
| Uniform `t_base`/`rh_base` (recommended) | One city-wide baseline; spatial variation only from land-cover offset; per-cell t_air/rh kept as metadata/v2 | |
| Per-cell `t_air`/`rh` + offset | Each cell uses its own CSV t_air/rh as base + offset; "same baseline" blurred, double-count risk | |
| Hybrid: `t_base` + per-cell `rh` | Uniform base temperature, per-cell humidity from data; more realistic, opens water–humidity coupling question | ✓ |

**User's choice:** Hybrid — `feels_like = HeatIndex(t_base + ΔT_UHI, rh_cell)`.
**Notes:** Derived decisions locked: `w_water` acts on the temperature input only; per-cell
`rh` taken as-is from the data file (no water→RH coupling in code) to avoid the PITFALLS-B3
double-count; the ordering test guarantees waterfront cells remain cooler overall.

---

## UHI Offset Structure (water-proximity term)

| Option | Description | Selected |
|--------|-------------|----------|
| Threshold near/far (recommended) | `Wprox = 1` if `water_km ≤ threshold` else `0`; add threshold param to namelist; matches v1 (REFN-02 deferred) | |
| Linear normalized | `Wprox = max(0, 1 − water_km/d_far)`; smoother, still not exp | |
| Exp decay (REFN-02/v2) | `Wprox = exp(−water_km/d0)`; best physics but is the deferred v2 feature | ✓ |

**User's choice:** Exp decay — continuous `Wprox = exp(−water_km/d0)`.
**Notes:** Pulls REFN-02 into v1 (move out of v2-deferred on next requirements update). Add a
tunable `d0` (~2.5 km default) to `data/coeffs.nml`. Phase-2 baseline uses `m = 1` (no
diurnal scaling — `m(t)` belongs to Phase 3).

---

## Heat-Index Algorithm

| Option | Description | Selected |
|--------|-------------|----------|
| Full NWS + floor `max(HI, t_air)` (recommended) | Steadman<80°F ↔ Rothfusz≥80°F + both RH adjustments; °F internal then convert; floor for HEAT-02 | ✓ |
| Two-branch, no adjustments | Steadman/Rothfusz without the high/low-RH adjustments; less code, drops humid-HCMC accuracy | |
| Rothfusz-only + clamp | Simplest; violates B1/HEAT-02 at cool/night cells — not recommended | |

**User's choice:** Full NWS algorithm + `feels_like = max(HI, t_air)` floor.
**Notes:** Includes the RH>85% & T 80–87°F adjustment (humid HCMC) and RH<13% adjustment.
Compute in °F with `_wp`-suffixed literals, convert to °C. Test vs NWS reference table + 80°F
boundary.

---

## Ordering Test Design (UHI-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Synthetic archetypes in-test (recommended) | Build controlled archetype cells (industrial/D1/park/Can Gio/rural) and assert ordering; robust to seed edits | ✓ |
| Real seed districts | Assert ordering directly on seed CSV; intuitive but brittle to data edits | |
| Property monotonicity only | Assert ↑building→↑, ↑tree→↓, etc.; tests monotonicity but not the composite headline ordering | |

**User's choice:** Synthetic controlled archetypes built inside the test.
**Notes:** Plus complementary property-monotonicity checks (↑building→↑feels-like,
↑tree→↓, ↑Wprox→↓, urban>rural). Verify by rank/sign, not absolute °C.

---

## Claude's Discretion

- Module names/APIs (`heat_index_mod`, `uhi_mod` per roadmap), derived-type field names.
- Exact `d0` default within ~2–3 km.
- How feels-like values are surfaced on the existing `app/main.f90` console output.
- Kernels must be `elemental pure`, no global state, consuming `grid_t` + `coeffs_t`.

## Deferred Ideas

- Diurnal `m(t)` + multi-timestep evaluation → Phase 3 (TIME-01/TIME-02).
- What-if scenarios / immutable baseline → Phase 3 (SCEN-01/SCEN-02).
- CSV export of feels-like / UHI columns → Phase 4 (OUT-01).
- Humidex toggle (REFN-01), cosine diurnal curve (REFN-03), more districts (REFN-04),
  seasonal runs (REFN-05) → v2.
- Night-gap calibration to ~3–8 °C → Phase 3 (depends on `m(t)`).
- REFN-02 (continuous water decay) is **no longer deferred** — brought into v1 this phase.
