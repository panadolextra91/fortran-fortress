---
phase: 2
phase_name: Feels-Like Physics (Heat Index + UHI Offset)
status: passed
verified: 2026-06-28
verified_by: manual review (build + 16 tests + run under strict flags)
requirements: [HEAT-01, HEAT-02, UHI-01, UHI-02]
---

# Phase 2 Verification — Feels-Like Physics (Heat Index + UHI Offset)

**Verdict: PASSED.** Code is correct, builds clean, all tests green under strict flags, and the
headline scientific pattern holds on the real seed data.

## Evidence (executed, not assumed)

Ran under `-fcheck=all -Wall -Wextra -fimplicit-none -finit-real=snan -ffpe-trap=invalid,zero,overflow`:

- `fpm build` — compiled successfully, **zero warnings**.
- `fpm test` — **16/16 tests PASSED**, exit 0:
  - `heat_index`: `ref_values`, `boundary` (NWS reference points incl. RH>85% adjustment + 80 °F boundary at the algorithm's 79.79 value).
  - `io`: 8 tests incl. `test_bad_d0` (fail-loud `d0 <= 0`).
  - `uhi`: `test_signs`, `test_monotonicity`, `test_magnitude` (single-digit budget).
  - `ordering`: `archetype_ordering` (UHI-02), `monotonicity` (D-11), `floor_edge` (D-09 floor vs `t_adj`).
  - `-ffpe-trap`/`-finit-real=snan` trapped **no** NaN or uninitialized reads → the `d0` divide is safe, no garbage propagation.
- `fpm run` — feels-like map produced on the 14-district HCMC seed (see ordering below).

## Success criteria (from ROADMAP §Phase 2)

1. **Per-cell feels-like from air temp + RH (HEAT-01)** — ✅ `feels_like_c` wired into the driver loop for every occupied cell.
2. **Range guard, no feels-like below air temp; 80 °F boundary test (HEAT-02)** — ✅ two-branch Steadman/Rothfusz + both RH adjustments; floor `max(HI, t_adj)`; boundary test asserts the computed 79.79 °F. No NaN at cool cells.
3. **Additive UHI offset, single documented budget, single-digit °C, waterfront cooler (UHI-01)** — ✅ `ΔT_UHI = w_build·B + w_urban·U − w_tree·V − w_water·exp(−water_km/d0)` applied once to the temperature input; magnitude test bounds it to single digits; waterfront/rural cells rank coolest.
4. **Dense treeless urban hotter than green/waterfront/rural, automated test (UHI-02)** — ✅ `test_archetype_ordering` PASSES; confirmed on real seed (below).

## Headline ordering on real seed (fpm run)

Industrial Binh Tan/Thu Duc ≈ 39.6/39.0 °C > urban cores (D3/D5/D10/Tan Binh/Go Vap 37–38.5, D1 36.2, Binh Thanh 35.3) > District 7 34.0 > Tao Dan Park 29.2 > Cu Chi rural 30.0 / Nha Be 26.6 / **Can Gio 24.6** (coolest). Dense-treeless-urban > park > waterfront/rural holds — the project's core value is met.

## Locked decisions D-01..D-11

All 11 implemented and represented in code/tests (hybrid base, water→temperature-only, single budget, exp-decay water term, `d0` in namelist + default 2.5, `m=1` no diurnal, full NWS two-branch + adjustments, °F-internal + `_wp`, floor vs `t_adj`, synthetic-archetype ordering test, property-monotonicity).

## Non-blocking observation (for Phase 4 / possible D-01 revisit)

The hybrid model (D-01) uses the uniform `coeffs%t_base` and **ignores per-cell `cell%t_air`** in the
feels-like math. The driver still **displays** per-cell `T=` (metadata) alongside `FEELS=`, so cool
cells show `FEELS < displayed T` (e.g. Can Gio `T=29.0 / FEELS=24.6`). This is **correct per D-01/D-09**
(the floor guarantees `FEELS ≥ t_adj`, not `≥ t_air`) — NOT the HEAT-02 bug — but it is an optics/
believability point: the seed's per-cell `t_air` values currently do not influence feels-like. Decide in
Phase 4 (output/summary) whether to display `t_base` instead of/alongside `t_air`, or revisit D-01 if
per-cell air temperature should drive the result.

---

*Verified: 2026-06-28 — Phase 2 complete.*
