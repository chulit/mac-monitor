# 01: Processes header, search filter, and summary stat cards

**What to build:** The top section of the Processes screen with header title, search bar, sort dropdown, live indicator, and 3 summary cards (Total Processes, CPU Usage with sparkline, Memory with sparkline).

**Blocked by:** None.

**Status:** ready-for-agent

- [x] Header displays "Processes" title and "Monitor resource usage and process relationships." subtitle
- [x] Search input with search icon and real-time filtering of the process list
- [x] Sort dropdown button (`CPU ≘`) and Live status badge (`• Live ⟳`)
- [x] 3 summary stat cards:
  - Total Processes count card (e.g. 184)
  - CPU Usage card (e.g. 18%) with smooth blue sparkline
  - Memory card (e.g. 12.4 GB) with smooth purple sparkline

## Comments

## Notes (2026-10-14)

- Sort hanya CPU/Nama/PID: engine tidak mengumpulkan memori per proses,
  jadi opsi sort memori akan menyiratkan data yang tidak ada.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
