# Plan 01 Summary

## Completed Tasks
- [x] Task 1: Extended `coeffs_t` and `coeffs.nml` to include the `base_*` and scenario delta fields (e.g. `base_morning`, `add_trees_delta`). The fields are loaded and strictly validated at runtime (e.g. out-of-range deltas are rejected loudly), addressing input boundary threats.
- [x] Task 2: Created `diurnal_mod` (`src/diurnal.f90`) which provides the 4 primary time labels (`T_MORNING`, `T_AFTERNOON`, etc.) and pure selectors (`diurnal_m`, `diurnal_base`, `time_label`) that evaluate safely over the config struct. Created and passed `test_diurnal`.
- [x] Task 3: Modified `feels_like_c` to take `m` as its 2nd positional argument, scaling the UHI offset computation dynamically. Replaced the flat query loop in `app/main.f90` with an encapsulated 4-timestep (`do it = 1, NT`) solver, projecting each cell across the full diurnal cycle natively. 

## Outcome
The core architectural change required for Phase 3 has been fully locked. The application loops across 4 timesteps (TIME-01) per occupied cell and threads the dynamic diurnal components—`m_t` and `base_t`—into the pure evaluation kernel (`feels_like_c`). Setting `m=1.0` successfully triggers regression stability against all Phase-2 validation checks, locking existing behavior safely while paving the way for multi-scenario delta simulations (the next plans).
