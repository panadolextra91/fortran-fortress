---
phase: 04-csv-export-console-summary
reviewed: 2026-06-30T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - app/main.f90
  - src/io.f90
  - src/summary.f90
  - test/test_output.f90
  - test/test_summary.f90
  - test/test_scenario.f90
findings:
  critical: 0
  warning: 5
  info: 3
  total: 8
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-06-30
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 4 adds output surfacing only: `write_results_csv` (src/io.f90), `hottest`/`coolest`
reductions (src/summary.f90), and driver wiring (app/main.f90), plus three tests. The
work is solid and the LOCKED invariants all hold:

- **OUTPUT-ONLY:** `git diff --name-only 90dd6aa^..HEAD` touches only io.f90, summary.f90,
  main.f90, and tests. No change to feels.f90, uhi.f90, diurnal.f90, scenario.f90,
  heat_index.f90. PASS.
- **t_air reference-only (D-03/WR-01):** `feels_like_c` is called with `base_t`
  (`diurnal_base`), never `t_air` (main.f90:96, 102). UHI is not double-counted. PASS.
- **Console prints feels-like only (D-08):** the baseline summary block (main.f90:121-134)
  prints hottest/coolest feels-like, city-avg, and U-R gap — no per-cell `t_air`. PASS.
- **Deterministic CSV (D-01/D-02/D-04):** header is byte-exact
  `i,j,name,time_label,scenario,t_air,base_t,feels_c,uhi_offset_c` (io.f90:304); iteration
  order is scenario -> timestep -> i -> j (io.f90:306-309); width-free `I0`/`F0.2` formats;
  unoccupied cells skipped (io.f90:310). 14 occupied x 3 scen x 4 NT = 168 data rows + 1
  header. PASS.
- **Modern idioms:** `implicit none`, `private` + explicit `public`, `use ..., only:`,
  `pure` reductions, `_wp` literals, `iostat`/`iomsg` checked on `open`. PASS.
- **snan safety:** `cell` has default real initializers (`= 0.0_wp`, grid.f90:9-13), so
  feels/uhi computed on unoccupied cells use defined zeros, not signalling NaN. PASS.
- **Empty-mask guard:** `hottest`/`coolest` guard `count(occupied)==0` before `maxloc`/
  `minloc` (summary.f90:50, 70). PASS.
- **test_scenario.f90 change:** the modification only adds explicit
  `building_delta = 0.0_wp` / `is_baseline = .false.` initializers before each
  `apply_scenario` call (4 sites). `scenario_t` already defaults these (scenario.f90:10-12),
  so the additions are redundant but harmless. No assertion was weakened or disabled.
  Legitimate.

No correctness, security, or data-loss defects were found. Remaining findings are
robustness and quality issues.

## Warnings

### WR-01: Sentinel index (0,0) from `hottest`/`coolest` is dereferenced unchecked

**File:** `app/main.f90:124-132`, `src/summary.f90:50-55, 70-75`
**Issue:** `hottest`/`coolest` return `ih=jh=0` (and `ic=jc=0`) when the grid has no
occupied cells. The driver immediately dereferences `baseline_grid%cells(ih,jh)%name`
and `cells(ic,jc)%name` without checking the sentinel. With the project's `-fcheck=all`
that is an out-of-bounds access on `cells(0,0)` -> runtime abort; without it, an
unallocated-`name` read on undefined memory. It is currently *latent* because
`read_grid_csv` rejects an empty grid (`ndist == 0` -> stat=1, io.f90:234-238), so the
driver never reaches the summary with zero occupied cells. But the contract between the
sentinel-returning reductions and the dereferencing caller is unguarded.
**Fix:** Guard the caller, e.g.:
```fortran
if (ih > 0 .and. jh > 0) then
    write(output_unit, ...) trim(baseline_grid%cells(ih,jh)%name), vh, ...
else
    write(output_unit, '(A)') trim(time_label(it)) // ': (no occupied cells)'
end if
```
or make `hottest`/`coolest` signal failure via a `logical, intent(out) :: ok` the caller
must inspect.

### WR-02: `write_results_csv` indexes `feels_all`/`uhi_all` without conformance check

**File:** `src/io.f90:306-316`
**Issue:** The loop bounds come from three independent sources — `size(scen_labels)` for
`iscen`, module constant `NT` for `it`, and `g%nx`/`g%ny` for `i`/`j` — but the array
references `feels_all(i,j,it,iscen)` / `uhi_all(i,j,it,iscen)` are never checked against
the actual extents of `feels_all`/`uhi_all`. If a future caller passes arrays whose 3rd
extent is `< NT` or 4th extent is `< size(scen_labels)` (or `g%nx/g%ny` exceed the array
shape), this silently reads out of bounds (or aborts under `-fcheck=all`). The current
driver call is consistent, so this is a robustness gap, not an active bug.
**Fix:** Assert conformance at entry and fail cleanly:
```fortran
if (size(feels_all,3) < NT .or. size(feels_all,4) < size(scen_labels) .or. &
    size(feels_all,1) < g%nx .or. size(feels_all,2) < g%ny) then
    stat = 1; msg = trim(path)//': result array shape mismatch'; return
end if
```
(and the same for `uhi_all`).

### WR-03: Console summary uses fixed-width `F7.2`/`F8.2`, reintroducing the `*****` risk

**File:** `app/main.f90:129`
**Issue:** The CSV path correctly uses width-free `F0.2` (PITFALLS §A9, no `*****`), but the
console summary format `'(A10,2X,A19,1X,F7.2,2X,A19,1X,F7.2,2X,F8.2,2X,F7.2)'` uses fixed
widths. `F7.2` overflows to `*******` for any value `>= 1000.00` or `<= -100.00`; `F8.2`
at `>= 10000.00` / `<= -1000.00`. Feels-like temperatures are bounded by the `T_MIN`/`T_MAX`
input validation and realistic heat-index output, so this will not overflow in practice —
but it is the same fragility §A9 warns against, and any unexpected value (e.g. a NaN slipping
through, which prints as `NaN`/`*`) degrades the human-readable summary.
**Fix:** Prefer width-free output for the numeric fields, e.g. format the value with `F0.2`
into a `character` buffer and place it in the table, or widen to a margin that cannot
overflow given the validated input ranges.

### WR-04: `maxloc`/`minloc` over a derived-type component mask creates a runtime array temporary

**File:** `src/summary.f90:57, 77` (`hottest`/`coolest`)
**Issue:** Surfaced by a functional `fpm run`/`fpm test` under the project strict flags
(`-fcheck=all`). `loc = maxloc(feels, mask=g%cells%occupied)` passes `g%cells%occupied` — a
strided component slice of a derived-type array — directly as the `mask=` actual argument,
which is non-contiguous, so gfortran materializes a contiguous copy and emits
`At line 57 of file ./src/summary.f90 / Fortran runtime warning: An array temporary was
created` (likewise line 77). Two consequences: (1) under the documented dev strict flags
these warnings print to stderr *interleaved with the OUT-02 console summary*, degrading the
"tiny readable report" deliverable (D-06); (2) the implicit per-call allocation is avoidable.
Clean under release flags (no `-fcheck`), but a real quality wart during development.
**Fix:** Copy the mask into a contiguous local `logical, allocatable :: mask(:,:)` first
(the idiom `urban_rural_gap` already uses, summary.f90:14-20), then pass `mask=mask` to the
intrinsic. Removes the temporary and tightens the call.

### WR-05: width-free `F0.2` drops the leading zero for |value| < 1 in CSV and console

**File:** `src/io.f90:314-316` (CSV `uhi_offset_c`), `app/main.f90:139-140` (scenario recap)
**Issue:** Surfaced by inspecting the generated `results.csv` and console output. gfortran's
width-free `F0.2` emits `.76` / `-.49` (no leading zero) for magnitudes below 1. This appears
in the CSV `uhi_offset_c` column (e.g. `-.49`, `.76`) and the console scenario recap
(`city-avg dT = .76 C`, `-.67 C`). These parse correctly in Excel / Python (`float('.76')`)
/ gnuplot, so OUT-01's "parses cleanly" criterion still holds and this is **not** a blocker —
but it is non-standard, ugly in the human-facing recap, and can surprise stricter downstream
parsers. (The fixed-width `F7.2`/`F8.2` console table at main.f90:129 is unaffected — fixed
widths keep the leading zero; only the width-free `F0.2` paths drop it.)
**Fix:** Format each affected real through a small helper that runs `F0.2` then prepends a
leading `0` (`.76`→`0.76`, `-.49`→`-0.49`), keeping the output width-free (A9-safe) and
`.`-decimal.

## Info

### IN-01: `base_t` recomputed in the innermost CSV loop

**File:** `src/io.f90:312`
**Issue:** `base_t = diurnal_base(c, it)` depends only on `it`, but is recomputed once per
occupied cell inside the `j`/`i` loops. Correct, just redundant and slightly obscures that
`base_t` is timestep-invariant.
**Fix:** Hoist it to the `it` loop:
```fortran
do it = 1, NT
    base_t = diurnal_base(c, it)
    do i = 1, g%nx
        do j = 1, g%ny
            ...
```

### IN-02: CSV `name` field is written without quoting/escaping

**File:** `src/io.f90:314-316`
**Issue:** `trim(g%cells(i,j)%name)` is emitted raw. A district name containing a comma (or
newline) would corrupt the CSV row/column count for downstream parsers. The project
explicitly accepts unquoted, comma-free district names (CLAUDE.md: "District seed data
won't [contain quoted commas] — keep it simple"), so this is by design and low risk.
**Fix:** None required under current constraints; if names ever become user-supplied, wrap
in quotes and double embedded quotes.

### IN-03: `uhi_offset_c` column carries the diurnally-scaled offset, not the raw offset

**File:** `app/main.f90:107-110`, `src/io.f90:304, 316`
**Issue:** The column header is `uhi_offset_c`, but the stored value is
`m_t * uhi_offset(...)` (the diurnally-applied offset = `t_adj - base_t`), not the raw
`uhi_offset(...)`. This is internally consistent — it equals exactly the UHI contribution
added to `base_t` inside `feels_like_c` — and is arguably the more useful quantity, but the
column name could mislead a consumer expecting the un-scaled coefficient output.
**Fix:** Optional — and the column MUST NOT be renamed: CONTEXT D-04 locks both the header
string `uhi_offset_c` and its semantics as "the **applied** offset at that timestep
(`m(t)·ΔT_UHI`)". So the stored `m_t * uhi_offset` is exactly per spec; the only safe option
is a data-dictionary/comment note. No code change.

## Resolution (2026-06-30)

Fixes applied directly (verified: full `fpm test` green + `fpm run` under strict flags
`-std=f2018 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -finit-real=snan`;
`results.csv` byte-identical across runs; 0 compiler warnings in io/summary/main).

| Finding | Status | What changed |
|---------|--------|--------------|
| WR-01 | ✅ Fixed | `app/main.f90` baseline-table loop guards `ih/jh/ic/jc > 0` before dereferencing `cells(...)%name`; prints `(no occupied cells)` on the sentinel. |
| WR-02 | ✅ Fixed | `src/io.f90 write_results_csv` asserts `feels_all`/`uhi_all` extents vs `nx/ny/NT/size(scen_labels)` at entry, returns `stat=1` + `result array shape mismatch` on a mismatch. |
| WR-03 | ⏸️ Accepted | Console `F7.2`/`F8.2` left as-is: feels temps are validation-bounded (no `*****` possible by construction) and width-free output would break the table's column alignment. Documented, no change. |
| WR-04 (F-A) | ✅ Fixed | `src/summary.f90 hottest`/`coolest` copy the occupied mask into a contiguous local `logical` array before `maxloc`/`minloc` — removes the runtime array temporary; console summary now prints clean (no `At line ...` stderr spam). |
| WR-05 (F-B) | ✅ Fixed | New `pure function real2str` in `io_mod` (public) runs `F0.2` then forces a leading zero (`.76`→`0.76`, `-.49`→`-0.49`), used by the CSV writer and the console scenario recap. Still width-free / `.`-decimal (A9-safe). |
| IN-01 | ✅ Fixed | `base_t = diurnal_base(c, it)` hoisted out of the `i`/`j` loops in `write_results_csv`. |
| IN-02 | ⏸️ Accepted | CSV `name` unquoted is by design (controlled comma-free seed data, CLAUDE.md). |
| IN-03 | ⏸️ N/A | `uhi_offset_c = m·uhi_offset` is exactly per locked CONTEXT D-04 (the *applied* offset). Header must not change. No defect. |

**New artifact:** `real2str` — public `pure function` in `io_mod` (`src/io.f90`).

---

_Reviewed: 2026-06-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Fixes applied + verified: 2026-06-30 (Claude, direct fix per user request)_
