# 05: Adaptive observation plus high-detail sessions

**What to build:** observation quality that degrades gracefully under budget and can be raised temporarily for one investigation, with every transition visible and recorded.

**Blocked by:** 04 (Evidence timeline plus process relevance).

**Status:** ready-for-agent

- [ ] Under budget pressure, noncritical work degrades first while minimum critical sampling is preserved, with actual intervals recorded
- [ ] Hysteresis prevents rapid mode flapping and quality recovers gradually
- [ ] Reduced monitoring shows an in-context indicator with its reason and affected metrics
- [ ] A user-requested high-detail session shows its limit and remaining time, warns before ending, ends automatically, and never extends silently
- [ ] Every quality transition is recorded on the timeline
