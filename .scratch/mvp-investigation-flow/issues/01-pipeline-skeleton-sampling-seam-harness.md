# 01: Pipeline skeleton plus sampling seam plus synthetic harness

**What to build:** the end-to-end path where timestamped samples flow through the sampling seam and incidents with evidence come out, driven by a deterministic synthetic stream on a controlled clock.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] Synthetic scenarios for normal operation, brief spike, sustained pressure, and missing data run reproducibly through the same seam production collectors will use
- [x] Samples carry timestamps and availability status; missing data is marked, never filled in
- [x] Duration-dependent behavior is reproducible via the injected clock, not wall time
- [x] The module accepts its collectors, clock, and storage rather than constructing them

## Comments

- Normal and missing-data scenarios run through the seam with gap marking and replay determinism verified. Spike and sustained-pressure scenario shapes need metric values on samples, which arrive with ticket 02's detection rules; 02 owns adding those scenarios.
- Closed: ticket 02 delivered `.spike` and `.sustainedPressure` through the same seam (locked by the spike-quiet and sustained-incident tests), so this criterion is now met.
