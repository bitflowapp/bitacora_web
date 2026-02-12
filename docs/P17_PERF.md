# P17 Perf Report

Date: 2026-02-12  
Environment: headless widget-test runtime (Windows), no GPU frame-timing pipeline.

## Instrumented Run
Command:

```powershell
flutter test test/editor_stress_smoke_test.dart --dart-define=BITFLOW_DEBUG_EDITOR_PERF=true
```

Observed output sample:
- `validation 19ms (rows=140, cols=15)`
- `surface=row window=2003ms grid=3 row=100 cell=990 input=0 latency(avg/p95/max)=0.0/0.0/0.0ms`
- `surface=row window=2000ms grid=11 row=414 cell=4140 input=0 latency(avg/p95/max)=0.0/0.0/0.0ms`
- `surface=row window=2000ms grid=14 row=586 cell=5860 input=0 latency(avg/p95/max)=0.0/0.0/0.0ms`
- `surface=mobile window=2033ms grid=16 row=646 cell=6470 input=0 latency(avg/p95/max)=0.0/0.0/0.0ms`

## What Changed in P17
- FlowBot path now offline-first and local-only (no remote token API path).
- Thumbnail decode cache now exposes:
  - entries/bytes
  - hit/miss counters
  - eviction counter
- Perf report payload (`Copy report` in `?perf=1`) now includes:
  - `thumb_cache_hits`
  - `thumb_cache_misses`
  - `thumb_cache_evictions`
- Perf overlay line now shows live cache efficiency (`H/M`) to detect decode churn quickly.

## Manual Repro (interactive)
1. Open editor with `?perf=1` or route `/perf`.
2. Run scenario from overlay (`Run scenario`).
3. Copy report and compare:
   - `grid_builds_window`, `row_builds_window`, `cell_builds_window`
   - frame `avg/p95/jank`
   - thumbnail cache `entries/bytes/hits/misses/evictions`

## Notes
- In headless widget tests, true device frame timings (GPU/vsync) are limited.
- Production jank verification should be done on physical iOS Safari + Android devices using `?perf=1`.
