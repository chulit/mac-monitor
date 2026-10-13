# 03: History detail header and incident overview summary

**What to build:** The header navigation and Overview summary card of the History Detail screen.

**Blocked by:** 02.

**Status:** ready-for-agent

- [x] Back button ("< Back to History") returning to the main History screen
- [x] Header with incident icon badge, title (e.g. "High CPU Usage"), timing metadata, and status badge (`Active`)
- [x] Overview summary card displaying structured metadata: Time, Duration, Peak CPU, Affected Processes, Status, and narrative Description

## Comments

## Notes (2026-10-14)

- Narasi disusun dari fakta tercatat; tanpa atribusi proses yang
  difabrikasi.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
