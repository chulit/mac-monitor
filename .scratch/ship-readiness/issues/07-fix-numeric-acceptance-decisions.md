# 07: Fix numeric acceptance decisions

**What to build:** every open number fixed before any release candidate: detection thresholds, resource budgets, retention periods, and detection-quality targets.

**Blocked by:** None (human decision; can start immediately).

**Status:** ready-for-human

- [x] Thresholds, budgets, retention periods, and quality targets are written down with reasons
- [x] Numbers are fixed before measurement, not fitted to results
- [x] Downstream tickets (benchmarks, gates) read these numbers instead of inventing their own

## Decisions (grilled 2026-10-13, all recommendations accepted as-is)

### Detection

- Critical CPU threshold: **0.90**
- Trigger duration: **30s** above threshold opens an incident
- Recovery duration: **30s** normal closes it
- Notification cooldown: **15 min** for the same recurring condition

### Baseline

- Promotion (candidate→active): **100** normal samples (~1.7 min at 1s cadence)
- Maturity (limited→stable): **1.000** samples (~17 min)
- Deviation threshold: **z-score 3.0**
- Staleness window: **1 hour** without normal samples

### Observation

- Budget definition: monitor's own CPU fraction; limit **0.02 (2%)**
- Hysteresis: **3** over-budget evaluations to degrade, **3** under to recover
- High-detail session cap: **600s (10 min)**

### Retention

- Detail retention: **7 days**, then summarize
- Quota unit is samples (engine counts samples): **150.000.000** (~8 days headroom at ~202 samples/s)

### Benchmark gates (smoke level; tightening needs separate justification)

- Wall **1s**, CPU **1s**, resident growth **100 MB**, block output **1.000** — identical for idle, normal, and investigation
