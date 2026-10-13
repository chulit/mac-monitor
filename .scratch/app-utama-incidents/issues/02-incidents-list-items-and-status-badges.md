# 02: Incidents list items and status badges

**What to build:** The scrollable list of incidents on the left panel with categorized anomaly badges, titles, responsible processes, relative timestamps, and active/resolved status tags.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] Render incident cards with category icon badges:
  - High CPU Usage (flame icon, red)
  - Memory Pressure (leaf/warning icon, orange)
  - Unusual Network Activity (pulse icon, blue)
  - Disk Activity Spike (hard drive icon, gray)
  - High Temperature (thermometer icon, orange)
  - Repeated App Crashes (crash/wave icon, blue)
  - App Not Responding (exclamation icon, amber)
- [x] Status pill badges: `Active` in red pill and `Resolved` in subtle gray pill
- [x] Relative timestamps (e.g. "2m ago", "1h ago") and trailing chevron
- [x] Selecting an incident highlights the card and loads its detail into the right panel

## Comments

## Notes (2026-10-14)

- Kategori yang tampil hanya yang diproduksi engine (cpu/memory/disk/
  network/unknown); temperature/crash/ANR tidak ada di model insiden.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
