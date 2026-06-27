# Feature Research

**Domain:** Urban heat island (UHI) / micro-climate illustration model (2D grid, scientific learning tool)
**Researched:** 2026-06-28
**Confidence:** HIGH (formulas + diurnal physics from primary sources; HCMC baselines from converging climate sources)

> Scope note: this file focuses on the **science features** the simulator must represent
> (heat-index formula, UHI offset parameterization, diurnal signature, HCMC baselines),
> since that is where "right vs wrong" lives for this project. Engineering/IO features
> (CSV writer, grid loader, CLI summary) are covered as table stakes but kept brief.

## Feature Landscape

### Table Stakes (Get These Wrong = the Model Is Wrong)

These are non-negotiable. The Core Value ("dense treeless cells must come out hotter than
green/waterfront cells, and the night gap must persist") fails without all of them.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Apparent-temperature (feels-like) per cell** | A UHI illustrator that ignores humidity is meteorologically wrong; HCMC is hot AND humid, so feels-like ≠ air temp | MEDIUM | Use NOAA Steadman/Rothfusz heat index OR humidex (see Candidate Formulas). Pure-function, easy to unit-test. |
| **Heat-index input-range guarding** | Rothfusz is only valid for HI ≳ 80 °F (26.7 °C) and breaks at extremes; night cells may fall below range | LOW | Below threshold, fall back to the simple Steadman average; clamp RH to 0–100. Skipping this produces nonsense at night. |
| **Additive UHI offset from land cover** | The entire point: building density ↑ and tree density ↓ must raise feels-like; water proximity + trees lower it | MEDIUM | Additive offset model (see Candidate Formulas). Transparency > precision for a teaching tool. |
| **Monotonicity / ordering correctness** | Urban core must rank hotter than rural/waterfront for the SAME baseline weather | LOW | This is the headline acceptance test. Verify by sorting cells, not by absolute °C. |
| **Diurnal (day–night) evaluation** | Night is when UHI is largest; a single snapshot hides the signature result | MEDIUM | Evaluate grid at ≥3 times (morning / mid-afternoon peak / night). Drive the UHI offset with a time-of-day multiplier (see Diurnal section). |
| **Nighttime-amplified urban–rural gap** | Reproducing "gap peaks at night" is the scientific payoff; if the gap shrinks at night the physics is inverted | MEDIUM | The offset multiplier must be LARGER at night than mid-afternoon. This is the most common modeling mistake — flag for a dedicated test. |
| **Grid loaded from a data file** | PROJECT requires real-ish HCMC district seed data, editable without recompiling | LOW–MEDIUM | Plain CSV/namelist reader. Fortran namelist or fixed-column CSV both fine. |
| **CSV export (one row per cell × timestep × scenario)** | Stated output contract; external plotting | LOW | Deterministic column order; include lat/lon or grid i,j, time label, scenario label. |
| **Console summary** | Stated requirement: hottest/coolest cell, city-average feels-like, urban–rural gap | LOW | Cheap reduction over the grid; doubles as a smoke test. |

### Differentiators (Where This Project Earns Its Value)

Aligned directly with PROJECT Core Value and Key Decisions.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **What-if scenario comparison** ("add trees" vs "more concrete") | The key illustrative payoff: quantify "+X trees → −Y °C". Turns a static map into an argument | MEDIUM | Re-run same grid with perturbed tree/building density; output per-cell and city-average Δ vs baseline. Pure rerun of the same kernel — low marginal cost once the kernel exists. |
| **Realistic HCMC baseline data** (District 1, Thu Duc, Can Gio…) | Relatable, sanity-checkable, compelling vs a synthetic random grid | LOW–MEDIUM | See HCMC Baselines. Can Gio (mangrove/coast) and parks are your natural "cool" controls; District 1 / industrial zones are "hot" controls. |
| **Explicit night-vs-day gap reporting** | Showing the gap *grow* after sunset is the memorable teaching moment | LOW | Just report gap per timestep in the summary + CSV; near-free given diurnal eval. |
| **Distance-to-water cooling term** | Waterfront/river cells visibly cooler — a feature most toy models omit | LOW–MEDIUM | Monotonic decay with distance (see formula). HCMC has the Saigon River + coast at Can Gio, so it shows up spatially. |
| **Tunable, documented coefficients** | Learners can edit weights and watch the map respond — transparency as a feature | LOW | Keep all weights in the data/config file, not hard-coded. Reinforces "illustrative, transparent" goal. |

### Anti-Features (Deliberately Do NOT Build)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Full CFD / 3D atmospheric & fluid dynamics** | "Make it physically real" | Months of work, numerically unstable, opaque, contradicts the "illustrative/transparent" goal; needs wind/turbulence fields you don't have | Parametric additive offset model. Already Out of Scope in PROJECT. |
| **Weather forecasting / predictive meteorology** | "Predict tomorrow's heat" | Requires data assimilation, NWP, validation infrastructure; the model illustrates *structure*, not future state | Scenario comparison answers "what if", which is the real question here. |
| **Live / real-time weather API ingestion** | "Use real current data" | Network dependency, API keys, schema churn, breaks the self-contained learning tool | Static realistic-ish seed file; refresh manually if desired. |
| **Per-building / sub-district resolution** | "More detail = better" | Data you don't have; grid blows up; spurious precision implies forecasting accuracy you can't deliver | District-scale cells (PROJECT constraint). |
| **GUI / web front-end / built-in plotting** | "See the map in-app" | Pulls Fortran toward UI it's bad at; doubles surface area | CSV → Excel/Python/gnuplot (stated contract). |
| **Wind & rain advection fields** | "Sea breeze cools the coast" | Needs vector fields, advection numerics, stability handling | Approximate the sea-breeze effect implicitly via the distance-to-water term. Defer real wind to a future milestone (PROJECT already notes this). |
| **Precise calibration against measured station data** | "Match real temperatures" | Implies predictive accuracy the model disclaims; endless tuning | Calibrate *qualitatively*: ranking + plausible gap magnitude (3–8 °C night UHI). |

## Candidate Formulas (Named, with Valid Ranges & Sources)

### 1. Apparent temperature — pick ONE primary

**Recommendation: NOAA/NWS Heat Index (Steadman→Rothfusz), with humidex as an easy alternative.**
Heat index is the most widely recognized "feels-like" and is what learners will expect to see;
humidex is arguably *better physics* for a tropical dew-point-dominated climate like HCMC. Both
are cheap pure functions. If you want one, ship Heat Index; offer humidex as a config toggle (low cost).

**(a) NWS simple Steadman approximation** — used when HI would be below ~80 °F. Compute in °F:
```
HI_simple = 0.5 * ( T + 61.0 + (T - 68.0)*1.2 + RH*0.094 )
HI_simple = average(HI_simple, T)   ! NWS averages with air temp
```
If `HI_simple < 80 °F`, this value is the result (don't apply Rothfusz).
T in °F, RH in %. (NWS WPC, [Heat Index Equation](https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml)) — **HIGH**

**(b) Rothfusz regression** — used when HI ≥ 80 °F. T in °F, RH in %:
```
HI = -42.379 + 2.04901523*T + 10.14333127*RH - 0.22475541*T*RH
     - 0.00683783*T*T - 0.05481717*RH*RH + 0.00122874*T*T*RH
     + 0.00085282*T*RH*RH - 0.00000199*T*T*RH*RH
```
Adjustments:
- If RH < 13% and 80 ≤ T ≤ 112 °F: subtract `((13-RH)/4)*sqrt((17-abs(T-95))/17)`
- If RH > 85% and 80 ≤ T ≤ 87 °F: add `((RH-85)/10)*((87-T)/5)`  ← **relevant for humid HCMC nights**

**Valid range:** T ≳ 80 °F (26.7 °C) and only within the Steadman data envelope; "not valid for
extreme T/RH beyond Steadman's range." Below 80 °F use formula (a).
(NWS WPC, [The Heat Index Equation](https://www.wpc.ncep.noaa.gov/html/heatindex_equationbody.html)) — **HIGH**

> Implementation note: the project works in °C (real64). Convert °C↔°F at the boundary
> (`F = C*9/5+32`), run the regression in °F, convert back. A direct °C-coefficient version of
> Rothfusz exists but mixing conventions is the classic bug — keep the canonical °F coefficients.

**(c) Humidex (alternative, dew-point based)** — arguably better for tropical humidity:
```
e   = 6.11 * exp( 5417.7530 * (1/273.16 - 1/(Td_K)) )   ! vapor pressure, hPa; Td_K = dewpoint in K
Hx  = T_C + 0.5555 * (e - 10.0)
```
Needs dew point (derive from T & RH via Magnus formula). Humidex uses a 7 °C dew-point base
vs heat index's 14 °C, and is "particularly meaningful in hot, humid areas" where sweat doesn't
evaporate — i.e. HCMC. (Stull, [Apparent Temperature Indices](https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/03:_Thermodynamics/3.07:_Apparent_Temperature_Indices); [Heat index — Wikipedia](https://en.wikipedia.org/wiki/Heat_index)) — **HIGH**

### 2. UHI land-cover offset — additive model

For a transparent teaching tool, an **additive offset** (not multiplicative on absolute °C) is the
right call: each driver contributes an interpretable ± °C. Drivers map 1:1 onto PROJECT inputs.

```
ΔT_UHI(cell) = m(t) * (  w_build * B                 ! building/impervious density  ∈[0,1], warms
                       + w_urban * U                 ! urban=1 / rural=0 flag,       warms
                       - w_tree  * V                 ! tree/canopy density          ∈[0,1], cools
                       - w_water * Wprox )           ! water-proximity factor        ∈[0,1], cools
feels_like(cell) = HeatIndex(T_base + ΔT_UHI, RH_base)
```
- `B, V` are fractional cover (0–1); `U` is the urban/rural class; `Wprox = exp(-d/d0)` decays
  with distance `d` to river/coast (`d0` a tunable scale length, e.g. ~2–3 km at district scale).
- `m(t)` is the **diurnal multiplier** (next section): the SAME land cover produces a bigger offset
  at night than at mid-afternoon.
- Suggested starting weights (tunable, illustrative — NOT calibrated): `w_build≈3.0`, `w_urban≈1.0`,
  `w_tree≈2.5`, `w_water≈2.0 °C`, chosen so peak night urban–rural gap lands in the realistic
  3–8 °C band (see below). **Keep these in the config file.**

Why additive & this sign structure: empirically UHI intensity rises with impervious-surface
fraction and falls with vegetation (NDVI) and water bodies; in HCMC parks/water bodies sit at
LST 23–25 °C while dense built-up zones exceed 30 °C, with industrial cores >45 °C.
(AccScience/AJWEP HCMC SUHI assessment; [PMC: density & morphology vs UHI intensity](https://pmc.ncbi.nlm.nih.gov/articles/PMC7253412/)) — **MEDIUM** (you are choosing illustrative weights, not fitting data)

### 3. Diurnal signature — why night, and how to model it simply

**Physics (for the docstring / teaching):** at night the urban–rural gap peaks because (i) concrete
& asphalt have high heat capacity/thermal inertia and release stored daytime heat slowly, while
rural vegetated surfaces cool fast via radiative loss + evapotranspiration; and (ii) the urban
canyon's **small sky-view factor** traps outgoing longwave radiation, suppressing nocturnal cooling.
Daytime UHI is typically 0.5–4 °C; **nocturnal peaks reach ~5–12 °C**.
(AMS [Thermal Effects of Urban Canyon Structure on the Nocturnal Heat Island](https://journals.ametsoc.org/view/journals/apme/43/12/jam2169.1.xml); Oke canyon-geometry/SVF work; [PMC: thermodynamics of urban nocturnal cooling](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5382147/)) — **HIGH**

**Simple model:** make the offset multiplier `m(t)` a function of time of day — small at the
mid-afternoon air-temp peak, large in the pre-dawn hours:

```
m(t):  morning (~07:00)  ≈ 0.5
       afternoon (~15:00) ≈ 0.3   ! air temp peaks, but UHI gap is SMALL
       evening (~21:00)   ≈ 0.8
       pre-dawn (~04:00)  ≈ 1.0   ! UHI gap is LARGEST
```
A lookup table over the chosen timesteps is enough; a smooth cosine `m(t)=m0+m1*cos(2π(t-φ)/24)`
phased to peak pre-dawn also works. **Critical correctness check:** mid-afternoon air temperature is
highest, but the urban–rural *gap* must be smallest then and largest pre-dawn — the offset (not the
baseline temp) carries the gap. Getting this backwards is the #1 pitfall.

## HCMC Baselines (Realistic Seed Values)

Tropical monsoon (Köppen Aw), hot year-round; **dry season Dec–Apr**, **wet season May–Nov**.
(climatestotravel; weather-atlas; weatherspark; weather-and-climate.com) — **HIGH**

| Parameter | Realistic range | Notes for seeding |
|-----------|-----------------|-------------------|
| Mean monthly air temp | 27 °C (Dec/Jan) → 30–30.5 °C (Apr/May) | Use ~28 °C as a generic baseline |
| Daily range (dry season hottest, April) | ~26 °C night → ~35–36 °C afternoon max | Drives the diurnal timesteps |
| Daily range (typical) | ~24 °C pre-dawn → ~33 °C afternoon | Use for morning/afternoon/night triplet |
| Relative humidity | 70% (Feb, driest) → 85% (Sep, wettest); annual avg ~78% | High RH → big feels-like uplift; use 70–85% |
| Annual rainfall | ~1,950 mm; >200 mm/month May–Oct | Not modeled; context only |
| Observed SUHI structure | Parks/water 23–25 °C LST; dense built-up >30 °C; industrial cores >45 °C; citywide mean LST 25.4 °C (1988) → 28.7 °C (2024) | Use as ranking/sanity targets, not as air-temp truth (LST ≠ 2 m air temp) |
| Nighttime warming trend | +0.23–0.3 °C/decade | Context for "night matters" narrative |

**Suggested district archetypes (for the seed file):**
- **District 1 / city core** — U=1, high B (~0.85), low V (~0.10), moderate water proximity (Saigon River) → hot.
- **Industrial zone (e.g. parts of Thu Duc/Binh Tan)** — U=1, very high B, ~0 V, low water proximity → hottest.
- **Park / green cell (e.g. Tao Dan area)** — U=1 but high V (~0.7), low B → local cool island.
- **Can Gio (mangrove/coast)** — U=0 (rural), V high, Wprox≈1 → coolest control.
- **Peri-urban/rural fringe** — U=0, low B, moderate V → rural reference for the urban–rural gap.

(HCMC SUHI: AccScience/AJWEP; [ScienceDirect Landsat UHI assessment](https://www.sciencedirect.com/science/article/abs/pii/S2210670716305807); [PMC green space & UHI mortality, HCMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5922196/)) — **MEDIUM/HIGH**

## Feature Dependencies

```
Grid-from-data-file
    └──required by──> Heat-index per cell ──> UHI additive offset ──> Diurnal evaluation
                                                                          └──> Night–day gap report
UHI additive offset
    └──required by──> Scenario comparison (re-runs the same kernel with perturbed B/V)
Diurnal multiplier m(t)  ──enables──> "gap peaks at night" (the signature result)
Heat-index range guard   ──prevents──> nonsense feels-like at cool night cells
Scenario comparison      ──depends on──> deterministic CSV schema (scenario + time labels)
```

### Dependency Notes
- **UHI offset requires heat-index kernel:** the offset perturbs air temp, which is then fed
  through the feels-like function — order matters (`HeatIndex(T+ΔT, RH)`).
- **Diurnal gap requires the m(t) multiplier on the offset, not on baseline temp:** baseline temp
  peaks in afternoon; the urban–rural *gap* must peak pre-dawn.
- **Scenario comparison enhances the offset model essentially for free:** it is the same kernel
  re-run with edited `B`/`V`; build the kernel as a pure function and scenarios fall out.
- **Range guard conflicts with naive Rothfusz:** applying Rothfusz below ~80 °F gives wrong values;
  guard branch is mandatory.

## MVP Definition

### Launch With (v1)
- [ ] Grid loaded from editable data file (cells + coefficients) — everything depends on it.
- [ ] Heat-index feels-like per cell **with range guard** (simple Steadman ↔ Rothfusz) — correctness.
- [ ] Additive UHI offset (building↑, urban↑, tree↓, water↓) — the core spatial pattern.
- [ ] Diurnal evaluation at ≥3 times with **night-amplified** offset — the signature result.
- [ ] CSV export (cell × time × scenario) + console summary (hottest/coolest/avg/gap).
- [ ] One baseline + at least one "add trees" and one "more concrete" scenario.

### Add After Validation (v1.x)
- [ ] Humidex toggle as alternative feels-like — once the HI path is trusted.
- [ ] Distance-to-water continuous decay (vs binary near/far) — once spatial pattern reads well.
- [ ] More districts / finer archetypes — once the 5-archetype set is validated.
- [ ] Smooth cosine diurnal curve replacing the lookup table.

### Future Consideration (v2+)
- [ ] Wind / sea-breeze advection (PROJECT flags as a future milestone).
- [ ] Seasonal runs (dry vs wet season baselines).
- [ ] Simple radiative/heat-balance term per cell (still parametric, not CFD).

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Heat-index feels-like + range guard | HIGH | MEDIUM | P1 |
| Additive UHI offset | HIGH | MEDIUM | P1 |
| Diurnal eval w/ night-amplified gap | HIGH | MEDIUM | P1 |
| Grid-from-data-file | HIGH | LOW | P1 |
| CSV export + console summary | HIGH | LOW | P1 |
| Scenario comparison | HIGH | MEDIUM | P1 |
| Realistic HCMC seed data | MEDIUM | LOW | P1/P2 |
| Continuous distance-to-water term | MEDIUM | LOW | P2 |
| Humidex alternative | LOW | LOW | P2 |
| Wind / sea-breeze, seasonal runs | MEDIUM | HIGH | P3 |

## Complexity Notes (per science feature)

- **Heat index:** LOW–MEDIUM. ~30 lines of branching arithmetic; the only trap is the °C↔°F
  convention and the <80 °F fallback. Highly unit-testable against the published NWS table.
- **UHI offset:** MEDIUM. Arithmetic is trivial; the work is *choosing defensible weights* so the
  night gap lands in 3–8 °C and ordering is always urban>rural. Budget time for tuning + a
  monotonicity test, not for code.
- **Diurnal signature:** MEDIUM. Code is a small lookup/cosine; the conceptual trap (gap peaks at
  night, not afternoon) deserves its own named test. This is the highest-value, highest-risk-of-
  silent-wrongness feature.
- **HCMC baselines:** LOW. Data entry into a seed file. Risk is conflating LST (satellite surface
  temp, used in most HCMC papers) with 2 m air temperature — use LST only for ranking sanity, set
  air-temp baselines from the climate normals (~28 °C, 70–85% RH).

## Sources

- NWS/WPC — [The Heat Index Equation (Rothfusz, body)](https://www.wpc.ncep.noaa.gov/html/heatindex_equationbody.html) — **HIGH**
- NWS/WPC — [Heat Index Equation (simple Steadman + adjustments)](https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml) — **HIGH**
- Stull, *Practical Meteorology* — [Apparent Temperature Indices (humidex, heat index, AT)](https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/03:_Thermodynamics/3.07:_Apparent_Temperature_Indices) — **HIGH**
- [Heat index — Wikipedia](https://en.wikipedia.org/wiki/Heat_index) (humidex vs heat index dew-point bases) — **MEDIUM**
- AMS J. Appl. Meteor. — [Thermal Effects of Urban Canyon Structure on the Nocturnal Heat Island](https://journals.ametsoc.org/view/journals/apme/43/12/jam2169.1.xml) — **HIGH**
- PMC — [Thermodynamic characterisation of urban nocturnal cooling](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5382147/) — **HIGH**
- PMC — [Influence of density and morphology on UHI intensity](https://pmc.ncbi.nlm.nih.gov/articles/PMC7253412/) — **MEDIUM**
- AccScience/AJWEP — [SUHI in Ho Chi Minh City (remote sensing & GIS)](https://accscience.com/journal/AJWEP/23/1/10.36922/AJWEP025260210) — **MEDIUM**
- ScienceDirect — [Urbanization & UHI in HCMC using Landsat](https://www.sciencedirect.com/science/article/abs/pii/S2210670716305807) — **MEDIUM**
- PMC — [Green Space & UHI-attributable deaths, HCMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5922196/) — **MEDIUM**
- HCMC climate normals — [climatestotravel](https://www.climatestotravel.com/climate/vietnam/ho-chi-minh), [weather-atlas](https://www.weather-atlas.com/en/vietnam/ho-chi-minh-city-climate), [weatherspark](https://weatherspark.com/y/116950/Average-Weather-in-Ho-Chi-Minh-City-Vietnam-Year-Round) — **HIGH**

---
*Feature research for: UHI / micro-climate illustration model (Ho Chi Minh City, modern Fortran)*
*Researched: 2026-06-28*
