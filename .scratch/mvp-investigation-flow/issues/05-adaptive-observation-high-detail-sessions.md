# 05: Adaptive observation plus high-detail sessions

**What to build:** observation quality that degrades gracefully under budget and can be raised temporarily for one investigation, with every transition visible and recorded.

**Blocked by:** 04 (Evidence timeline plus process relevance).

**Status:** ready-for-agent

- [x] Under budget pressure, noncritical work degrades first while minimum critical sampling is preserved, with actual intervals recorded
- [x] Hysteresis prevents rapid mode flapping and quality recovers gradually
- [x] Reduced monitoring shows an in-context indicator with its reason and affected metrics
- [x] A user-requested high-detail session shows its limit and remaining time, warns before ending, ends automatically, and never extends silently
- [x] Every quality transition is recorded on the timeline

## Comments

- Observation policy is injected config (budget limit, critical metrics, intervals, hysteresis counts, session cap and warning window); usage arrives per evaluation, so the controlled clock keeps every transition deterministic.
- High-detail sessions take precedence over budget pressure with frozen streaks; expiry reverts to normal with fresh streaks. A repeat request while active is ignored — never extended silently. Durations clamp to the policy maximum.
- Incident timelines carry the observation transitions overlapping their span; the evaluation also reports the current mode, per-metric intervals, observed intervals, and that evaluation's new transitions.
- Known limits, owned by later tickets: episode continuity and cooldown across evaluate calls stay per-batch; scheduler-driven collection (acting on the recommended intervals) does not exist yet — the engine publishes them.
