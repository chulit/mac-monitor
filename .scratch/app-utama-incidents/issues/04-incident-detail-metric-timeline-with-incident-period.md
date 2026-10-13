# 04: Incident detail metric timeline with shaded incident period

**What to build:** The timeline graph in the incident detail pane with metric tabs, shaded incident span, and interactive peak point tooltip.

**Blocked by:** 03.

**Status:** ready-for-agent

- [x] Metric selector tabs: `[ CPU | Memory | Disk | Network | Temperature ]`
- [x] Timeline area graph showing the metric trajectory leading up to and during the incident
- [x] Shaded incident span background highlighting the active duration of the incident
- [x] Interactive peak tooltip indicating exact peak time and percentage (e.g. `10:13:24 • CPU 92%`) with a vertical guideline and data point circle

## Comments

## Notes (2026-10-14)

- Tab hanya untuk metrik yang benar-benar ada di sampel timeline.
- Tooltip drag-to-inspect; penanda peak dari sampel maksimum asli.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
