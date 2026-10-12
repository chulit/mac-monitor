# 04: Evidence timeline plus process relevance

**What to build:** every incident opens onto a synchronized timeline with evidence-graded process relevance, where correlation is never presented as causation.

**Blocked by:** 03 (Baseline learning plus contextual deviation).

**Status:** ready-for-agent

- [x] Each incident shows related metrics on a single synchronized timeline with event markers and monitoring-status changes
- [x] Sampling gaps and access limitations appear on the timeline where the evidence is thin
- [x] The timeline notes which rule and baseline versions produced the finding
- [x] Each ranked process states its evidence-based reason for relevance
- [x] Timing and parent-child proximity are never stated as cause-and-effect

## Comments

- Monitoring-status-change markers arrive with ticket 05 (observation quality does not exist yet); incident start/peak/recovery markers are in place.
- Samples carry metric identity; baselines are keyed per metric, which also makes per-metric recalibration fall out naturally later. Metric names are test-local vocabulary — the PRD metric list is still open.
- Process identity here is an opaque string id; real PID-plus-exec-identity arrives with host collector adapters.
- Relevance reasons come from a closed vocabulary (largest/elevated share, ancestor-of); a test asserts no reason contains causal language, and cyclic parent links are proven to terminate.
- Ancestor-only entries carry measured share (zero when unobserved) with a relational reason — relational, not measured, relevance.
