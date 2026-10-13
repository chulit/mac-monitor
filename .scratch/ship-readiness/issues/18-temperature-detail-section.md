# 18: Temperature detail section with per-component bars

**What to build:** the mockup's temperature breakdown (CPU average/performance/efficiency, GPU, SSD) as labeled bars in the popover.

**Blocked by:** 16 (Temperature sensor collectors).

**Status:** ready-for-agent

- [x] Each available component renders its labeled bar and value; unavailable components are labeled, not zeroed
- [x] Bars reflect live readings on every tick, with no fabricated interpolation
- [x] Views stay thin with no new test seam

## Comments

- Six rows: the mockup's five plus CPU (Secondary sensor) for Tp05, whose exact role is undocumented — labeled plainly rather than forced into the Performance/Efficiency slots. Performance, Efficiency, and GPU render unavailable; no such keys exist on this model.
- Bars scale to a fixed 0–100°C so they never rescale-jitter between ticks. The chevron collapses the section for real. The section hides entirely when no temperature reading is fresh.
- Verified by warning-free build plus the untouched engine suite (no UI seam, per agreement).
