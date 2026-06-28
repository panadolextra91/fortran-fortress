# Plan 01 Summary

## Completed Tasks
- [x] Task 1: Extended `constants_mod` with `c_to_f`/`f_to_c` and named Rothfusz coefficients.
- [x] Task 2: Created `heat_index_mod` with the elemental pure NWS two-branch kernel.
- [x] Task 3: Created `test/test_heat_index.f90` which verifies the NWS reference values, the 80 °F boundary, and the cool/dry corner.

## Outcome
The core heat-index physics is implemented following the exact NWS algorithm (Steadman < 80 °F, Rothfusz otherwise, with RH adjustments) and runs entirely in °F internally. All constraints (D-07, D-08) are met. The test suite passes.
