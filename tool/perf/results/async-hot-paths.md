# Async hot-path benchmark

These are controlled local repository measurements with simulated I/O, not production or device latency.
The old and new implementations complete the same work. All measured requests succeeded.

## Results

Each percentile uses 100 samples per side, pooled from five runs. Units: milliseconds. Lower is better.

| Path | p50 before → after | p90 before → after |
|---|---:|---:|
| Analytics dispatch (3 providers) | 47.0 → 19.9 | 56.0 → 21.6 |
| Favourite counts (150 walls) | 80.0 → 28.8 | 87.6 → 38.2 |
| User search (8 registry profiles) | 179.2 → 60.1 | 262.1 → 72.0 |

The [graphs](async-hot-paths.html) use a shared scale. The [raw samples](async-hot-paths.json) include all runs and profiles.

## Repeatability

Each cell is the median of five run percentiles, followed by the minimum and maximum. Units: milliseconds.

| Path and percentile | Before median (range) | After median (range) |
|---|---:|---:|
| Analytics dispatch (3 providers): p50 | 46.6 (45.9–48.0) | 19.5 (18.9–20.0) |
| Analytics dispatch (3 providers): p90 | 54.5 (50.3–60.8) | 21.6 (20.9–24.2) |
| Favourite counts (150 walls): p50 | 79.5 (76.7–82.2) | 28.6 (26.7–30.4) |
| Favourite counts (150 walls): p90 | 87.0 (82.5–89.1) | 38.2 (32.3–52.9) |
| User search (8 registry profiles): p50 | 184.0 (168.9–186.0) | 60.0 (59.9–62.0) |
| User search (8 registry profiles): p90 | 237.8 (190.7–466.4) | 67.8 (62.9–138.4) |

## Method

- Baseline: `4cadbae60a0b86d9fcb467b23c62f76fee8d101c`. The runner extracts the three old source files without changing the working tree.
- Candidate source hashes are in the JSON. Both versions run in the same Flutter test process with the same dependencies.
- Each side has five runs of 20 samples. The first side alternates for each sample. Five unreported warmup/profile requests precede each side.
- Each dependency call waits 8–20 ms. Its delay depends only on the sample and dependency key, not execution order.
- Analytics completes three provider calls. Favourite counts returns 150 correctly parsed records through five queries.
- Search performs 12 dependency calls and returns eight profiles in registry order. Every sample checks outputs, counts, and completion.
- Lookup concurrency stays at four or fewer. Samples time complete public method calls, including result checks.
- Percentiles use the nearest-rank method. A failed request aborts the benchmark; failed runs do not produce new samples.
- Runtime: FVM Flutter test (debug/JIT), Linux, 4 visible CPUs. Initial load averages: 26.3, 23.4, 48.9.
- The shared host was busy. Paired samples reduce drift but do not remove scheduling noise. These results do not establish production speedups.

## Limiter and limits

The controlled limiter is time spent at the simulated async boundary in `Boundary.read`, not real network or database bandwidth.
Independent awaits overlap those waits. The final dependency, later bounded batches, Dart work, and host scheduling still limit latency.
No reads or provider calls are removed. The unreported profiles record wall time and Linux user/system CPU ticks at 100 ticks/second.
Peak in-flight counts are in the raw data. These counters and output assertions establish that the work completed in the timed region.

This benchmark excludes Flutter rendering, native plugins, Firebase RPCs, real transaction contention, retries, and production caches.
It covers three representative paths, not all changed paths. Live p50/p90 and app-wide latency remain unmeasured.
The backend transaction tests establish one read round, not a millisecond latency improvement.

## Reproduce

```sh
node tool/perf/async_hot_paths.mjs 4cadbae60a0b86d9fcb467b23c62f76fee8d101c
node tool/perf/async_hot_paths_report.mjs
```
