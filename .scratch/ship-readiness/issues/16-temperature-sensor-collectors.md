# 16: Temperature sensor collectors

**What to build:** real temperature and per-component readings (CPU average/performance/efficiency, GPU, SSD) flowing through the sampling seam, built on ticket 15's research verdict.

**Blocked by:** 15 (Temperature and per-component sensor research).

**Status:** ready-for-agent

- [ ] Collectors read the researched sensors unprivileged where the verdict allows, with honest unavailable elsewhere
- [ ] Readings carry metric identity and timestamps through the existing seam; existing suites stay green
- [ ] Model-specific behavior is recorded, not assumed across models
