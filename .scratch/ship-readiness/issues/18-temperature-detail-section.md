# 18: Temperature detail section with per-component bars

**What to build:** the mockup's temperature breakdown (CPU average/performance/efficiency, GPU, SSD) as labeled bars in the popover.

**Blocked by:** 16 (Temperature sensor collectors).

**Status:** ready-for-agent

- [ ] Each available component renders its labeled bar and value; unavailable components are labeled, not zeroed
- [ ] Bars reflect live readings on every tick, with no fabricated interpolation
- [ ] Views stay thin with no new test seam
