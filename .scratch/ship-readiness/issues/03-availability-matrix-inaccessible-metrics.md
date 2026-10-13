# 03: Availability matrix for inaccessible metrics

**What to build:** every supported Mac model reporting each metric as available or honest-unavailable, with no zeros and no fabrication.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [ ] The Apple Silicon and Intel support matrix records which metrics each model provides
- [ ] Inaccessible metrics surface as unavailable in every surface (dashboard, timeline, export)
- [ ] No unavailable metric is ever shown as zero or normal
