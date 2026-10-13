# 03: Process detail header, navigation tabs, and metric stat cards

**What to build:** The top navigation, app header, sub-navigation tabs, and 4 metric stat cards of the Process Detail screen.

**Blocked by:** 02 (process table).

**Status:** ready-for-agent

- [x] Back navigation button ("< Back to Processes") returning cleanly to the process list
- [x] Process header displaying large application icon, app name, "● Running" status badge, developer, version, launch timestamp, and action buttons ("···", "📁 Open in Finder")
- [x] Sub-navigation pill tabs: `[ Overview | Performance | Threads | Files & Connections | Incidents ]`
- [x] 4 metric stat cards:
  - CPU Usage (with blue sparkline)
  - Memory Usage (with purple sparkline)
  - Disk Activity (with green sparkline)
  - Network Activity (with orange/cyan sparkline)

## Comments

## Notes (2026-10-14)

- Metadata via NSRunningApplication + proc_pidpath (asli); yang tidak
  tersedia (developer, dsb.) tampil "—".
- Kartu Memory/Disk/Network menampilkan "—": engine tidak mengumpulkan
  telemetri per proses selain CPU.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
