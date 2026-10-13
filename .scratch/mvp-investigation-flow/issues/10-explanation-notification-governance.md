# 10: Minimal on-device explanation plus notification governance

**What to build:** optional on-device help that separates facts from hypotheses, with notifications governed so users are informed once, not nagged.

**Blocked by:** 04 (Evidence timeline plus process relevance), 08 (Dashboard plus process tree plus timeline surfaces).

**Status:** ready-for-agent

- [x] Explanations separate measured facts, temporal correlation, causal hypotheses, uncertainty, and unavailable data
- [x] Explanations never fabricate metrics, never guarantee causation without evidence, and never perform system actions
- [x] Core monitoring works fully without on-device AI and without any cloud fallback
- [x] Notifications follow severity, duration, recurrence, cooldown, deduplication, and recovery, distinguishing normal, active anomaly, and limited observation

## Comments

- Explanation is a pure mapping over incident timelines: every number is computed from recorded evidence, hypotheses are explicitly marked unproven (with an explicit none-available case), and nothing executes.
- The notifier is additive state behind the existing seam: per-condition keys of start, source, and metrics drive started/recovered notices with injected severity and cooldown policy; repeat evaluations never re-notify, and recurrences within cooldown stay silent on start while still reporting recovery.
- Observation notices fire only on transitions into and out of reduced monitoring (silent-first baseline); limited episodes carry their reason and affected metrics.
- All 43 prior tests pass without touching either module, which is the standing proof that core monitoring works without them and without any cloud fallback.
