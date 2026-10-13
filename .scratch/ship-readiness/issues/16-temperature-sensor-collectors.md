# 16: Temperature sensor collectors

**What to build:** real temperature and per-component readings (CPU average/performance/efficiency, GPU, SSD) flowing through the sampling seam, built on ticket 15's research verdict.

**Blocked by:** 15 (Temperature and per-component sensor research).

**Status:** ready-for-agent

- [x] Collectors read the researched sensors unprivileged where the verdict allows, with honest unavailable elsewhere
- [x] Readings carry metric identity and timestamps through the existing seam; existing suites stay green
- [x] Model-specific behavior is recorded, not assumed across models

## Comments

- `TemperatureCollector` holds one SMC connection and reads the verdict's keys (`temperature`, `temperature.secondary`, `temperature.storage`) as Celsius point-in-time samples; each unreadable key reports unavailable without failing the batch.
- Forced a load-bearing engine fix along the way: rules now accept an optional metric scope, because absolute thresholds are meaningless for unbounded (network) and physical-unit (temperature) series. The live app scopes rules to fraction metrics; baselines still learn every metric.
- Intel temperature rows stay out of the matrix: the collector only knows verified M2 keys, so listing them would be a claim without evidence.
