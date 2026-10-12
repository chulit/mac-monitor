# 03: Baseline learning plus contextual deviation

**What to build:** a locally learned baseline with visible maturity that raises contextual incidents through the same lifecycle without ever suppressing critical rules.

**Blocked by:** 02 (Critical rules plus incident lifecycle).

**Status:** ready-for-agent

- [x] The baseline learns only from samples judged normal; known anomalies and incidents are excluded
- [x] Candidate and active generations exist with visible status: Learning, Limited, Stable, or Stale
- [x] Baseline changes record time, reason, algorithm version, and qualifying sample count
- [x] Contextual deviations raise incidents through the same create/update/recover lifecycle
- [x] An immature baseline never suppresses technical rules, and only impacted metrics recalibrate after major system change

## Comments

- Detection uses the pre-batch active baseline, then the batch is learned: a level shift is flagged against prior normal rather than absorbed. Locked by test.
- Deviation detection reuses the episode scanner via a deviation-magnitude transform (one implementation, rule and baseline call sites).
- `ControlledClock` is a reference type so the pipeline observes the same time the driver advances; `Sendable` was dropped from the `Clock` protocol accordingly.
- Known limits, owned by later tickets: episode continuity and cooldown across evaluate calls are per-batch (multi-batch history arrives with retention work); stale baselines still feed detection; per-metric recalibration is N/A in single-metric scope; incidents carry no rule identity yet.
