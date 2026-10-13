# 05: History detail affected processes, system context, and actions

**What to build:** The Affected Processes table, System Context card, and Actions card in the History Detail screen.

**Blocked by:** 04.

**Status:** ready-for-agent

- [x] "Affected Processes" card displaying contributing processes with app icons, names, Peak CPU, and Average CPU
- [x] "System Context" card displaying concurrent auxiliary conditions: Memory Usage (e.g. 14.8 GB (78%)), Disk Activity (98 MB/s), Network Activity (12 MB/s)
- [x] "Actions" card with interactive action buttons:
  - "View Related Processes" (styled in primary blue)
  - "Create Exclusion"
  - "Share Incident" (triggering incident package export)

## Comments

## Notes (2026-10-14)

- Affected Processes: share kontribusi dari timeline live; empty state
  untuk insiden lama. System Context dari sampel terdekat peak.
- "View Related Processes" scroll ke kartu Affected Processes;
  "Create Exclusion" belum diimplementasikan (alert jujur).
- "Share Incident": export package asli (`IncidentArchive.export`) via
  NSSavePanel.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
