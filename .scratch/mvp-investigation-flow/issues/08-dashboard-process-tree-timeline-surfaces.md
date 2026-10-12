# 08: Dashboard plus process tree plus timeline surfaces

**What to build:** a simple-at-rest interface that discloses depth on demand, with honest unavailable and reduced-monitoring states everywhere they matter.

**Blocked by:** 05 (Adaptive observation plus high-detail sessions).

**Status:** ready-for-agent

- [ ] The normal dashboard stays simple; advanced detail appears only when needed
- [ ] The process tree supports search, filter, expand, and collapse, with subtree aggregates stated separately from individual process metrics
- [ ] The investigation timeline uses one synchronized axis with tooltips across metrics and event markers
- [ ] Unavailable metrics are labeled unavailable, never shown as zero
- [ ] Reduced monitoring shows its reason and affected metrics in context, and monitoring status is never presented as system health
