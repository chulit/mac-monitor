# 01: History header and system activity trend chart

**What to build:** The top section of the History screen with header controls (date range dropdown "Last 7 Days", search input) and the System Activity trend card with metric selector tabs (`[ CPU | Memory | Disk | Network | Temperature ]`), multi-day curve, and inspection tooltip.

**Blocked by:** None.

**Status:** ready-for-agent

- [x] Header with "History" title, "View system activity, incidents, and resource usage over time." subtitle, date dropdown, and search input
- [x] System Activity card with metric selector tabs: `[ CPU | Memory | Disk | Network | Temperature ]`
- [x] Multi-day timeline area graph with daily timestamp labels along the X-axis (e.g. Apr 22 to Apr 28)
- [x] Interactive hover tooltip displaying timestamp and metric value (e.g. `Apr 25, 2025 14:32 • CPU 78%`)

## Comments

## Notes (2026-10-14)

- Grafik dari `activitySeries`: rata-rata per bucket (maks 300 titik),
  menggabungkan detail + summary retensi.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
