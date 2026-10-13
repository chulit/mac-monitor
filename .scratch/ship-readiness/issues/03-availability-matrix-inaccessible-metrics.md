# 03: Availability matrix for inaccessible metrics

**What to build:** every supported Mac model reporting each metric as available or honest-unavailable, with no zeros and no fabrication.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [x] The Apple Silicon and Intel support matrix records which metrics each model provides
- [x] Inaccessible metrics surface as unavailable in every surface (dashboard, timeline, export)
- [x] No unavailable metric is ever shown as zero or normal

## Comments

- `CapabilityMatrix` declares per-architecture expectations from a runtime `hw.machine` probe; both supported architectures share Mach-based collectors today, and unknown hardware conservatively supports nothing. The probe-failure path is review-only coverage.
- Unavailable flows end to end without distortion: evaluation gaps, span-scoped timeline gaps, "data unavailable" tooltips with no fabricated readings, and gap-preserving export. The locking test pins both gap levels after an initial over-specific expectation caught the span scoping working as designed.
