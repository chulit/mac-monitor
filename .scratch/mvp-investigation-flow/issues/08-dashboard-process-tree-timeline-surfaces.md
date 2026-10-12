# 08: Dashboard plus process tree plus timeline surfaces

**What to build:** a simple-at-rest interface that discloses depth on demand, with honest unavailable and reduced-monitoring states everywhere they matter.

**Blocked by:** 05 (Adaptive observation plus high-detail sessions).

**Status:** ready-for-agent

- [x] The normal dashboard stays simple; advanced detail appears only when needed
- [x] The process tree supports search, filter, expand, and collapse, with subtree aggregates stated separately from individual process metrics
- [x] The investigation timeline uses one synchronized axis with tooltips across metrics and event markers
- [x] Unavailable metrics are labeled unavailable, never shown as zero
- [x] Reduced monitoring shows its reason and affected metrics in context, and monitoring status is never presented as system health

## Comments

- Implemented as engine-backed view state (`Presentation.swift`), per the agreed scope: pure mappings over existing engine outputs, no views, no new seam. A future app target consumes these types directly.
- The engine layer never assesses system health: `SystemHealth` has only `.unknown`, asserted in every mode. Monitoring headlines name observation quality only.
- Gap records carry no metric identity, so timeline tooltips label missing data without attributing it to a metric; per-metric gap attribution is follow-up work for host collectors.
- Cyclic parent links terminate in tree rows (no roots exist, so no rows).
