---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 3
current_phase_name: Day-Night Cycle & Scenario Comparison
status: executing
stopped_at: Phase 3 context gathered
last_updated: "2026-06-29T04:29:43.479Z"
last_activity: 2026-06-28
last_activity_desc: "Phase 2 complete (3 plans, verified): feels-like physics + UHI-02 ordering"
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 6
  completed_plans: 6
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-28)

**Core value:** The simulated heat map must be scientifically believable — dense, treeless
urban cells come out hotter than green/waterfront/rural cells, and the night-time urban-rural
gap persists/grows — for the same baseline weather.
**Current focus:** Phase 3 — Day-Night Cycle & Scenario Comparison

## Current Position

Phase: 3 of 4 (Day-Night Cycle & Scenario Comparison)
Plan: not yet planned
Status: Ready to discuss/plan
Last activity: 2026-06-28 — Phase 2 complete (3 plans, verified): feels-like physics + UHI-02 ordering

Progress: [█████░░░░░] 50%

## Phase Completion Log

| Phase | Name | Plans | Status | Completed |
|-------|------|-------|--------|-----------|
| 1 | Build Scaffold & Grid Loader | 3/3 | ✅ Complete | 2026-06-28 |
| 2 | Feels-Like Physics (Heat Index + UHI Offset) | 3/3 | ✅ Complete (verified) | 2026-06-28 |

## Performance Metrics

**Velocity:**

- Total plans completed: 6
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Build Scaffold & Grid Loader | 3 | — | — |
| 2. Feels-Like Physics (Heat Index + UHI Offset) | 3 | — | — |

**Recent Trend:**

- Last 5 plans: 01-03, 02-01, 02-02, 02-03
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Build with fpm (vs plain Makefile) — auto-resolves module compile order; Phase 1 retires the Hello-World Makefile scaffold.
- [Roadmap]: 4 coarse horizontal-layer phases following the acyclic module build order (foundation/grid → physics → diurnal/scenarios → output).
- [Roadmap]: Two headline science invariants pinned as tested success criteria — UHI-02 (urban>rural ordering) in Phase 2, TIME-02 (`gap_night > gap_afternoon`) in Phase 3.
- [Phase 1]: 01-04 (seed data + driver + config round-trip test) was consolidated into 01-02 + 01-03 during execution — Phase 1 shipped as 3 plans delivering GRID-01..04.
- [Phase 2]: Complete + verified (build clean, 16/16 tests pass under strict flags, UHI-02 ordering holds on real seed). See 02-VERIFICATION.md.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

- [Phase 3]: UHI weights are illustrative, not fitted — tune so the peak night urban-rural gap lands in ~3-8 °C while ordering stays urban>rural (research gap).
- [Phase 2 ✅ resolved]: Heat-index unit convention — canonical Rothfusz in °F, presented in °C; 80 °F boundary validated by test (B1).
- [Phase 4]: Hybrid model (D-01) uses uniform `t_base` and ignores per-cell `cell%t_air` in the feels-like math, but the driver still displays per-cell `T=` next to `FEELS=`, so cool cells show `FEELS < displayed T` (e.g. Can Gio T=29.0 / FEELS=24.6). Correct per D-09 floor (vs `t_adj`, not `t_air`) — NOT the HEAT-02 bug — but an optics point: decide in Phase 4 whether to display `t_base` instead of/alongside `t_air`, or revisit D-01 if per-cell air temp should drive the result. (See 02-VERIFICATION.md.)

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-06-29T04:29:43.472Z
Stopped at: Phase 3 context gathered
Resume file: .planning/phases/03-day-night-cycle-scenario-comparison/03-CONTEXT.md
