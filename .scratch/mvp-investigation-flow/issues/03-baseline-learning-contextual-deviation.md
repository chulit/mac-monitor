# 03: Baseline learning plus contextual deviation

**What to build:** a locally learned baseline with visible maturity that raises contextual incidents through the same lifecycle without ever suppressing critical rules.

**Blocked by:** 02 (Critical rules plus incident lifecycle).

**Status:** ready-for-agent

- [ ] The baseline learns only from samples judged normal; known anomalies and incidents are excluded
- [ ] Candidate and active generations exist with visible status: Learning, Limited, Stable, or Stale
- [ ] Baseline changes record time, reason, algorithm version, and qualifying sample count
- [ ] Contextual deviations raise incidents through the same create/update/recover lifecycle
- [ ] An immature baseline never suppresses technical rules, and only impacted metrics recalibrate after major system change
