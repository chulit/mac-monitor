# 01: Incidents split layout and filter tabs

**What to build:** Master-detail split layout for the Incidents screen, with header, status filter pills (`[ All | Active | Resolved ]`), and date range dropdown ("Last 7 Days ∨").

**Blocked by:** None.

**Status:** ready-for-agent

- [x] Split view structure with list panel on the left and detail panel on the right matching `incidents.png`
- [x] Header with "Incidents" title and "Detected anomalies and notable system events." subtitle
- [x] Filter tab control switching between `All`, `Active`, and `Resolved`
- [x] Date range dropdown menu ("Last 7 Days", "Last 24 Hours", etc.)

## Comments

## Notes (2026-10-14)

- Master-detail kustom (bukan NavigationSplitView) karena sudah berada di
  dalam kolom detail NavigationSplitView utama.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
