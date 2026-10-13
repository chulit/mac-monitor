# 02: Overview header, monitoring status, and investigation controls

**What to build:** The header section of the Overview screen with dynamic monitoring status indicator, time range picker menu ("Last 1 Hour"), and "Start Investigation" / "Stop Investigation" toggle button hooked to engine high-detail mode.

**Blocked by:** 01 (navigation sidebar foundation).

**Status:** ready-for-agent

- [x] Displays prominent "Overview" title conforming to macOS standard font sizes
- [x] In normal state, displays green status indicator, "Monitoring Normal", and "All systems are running smoothly."
- [x] In investigating state, displays active spinning indicator, "Investigating...", and diagnostic status subtitle
- [x] Time range dropdown menu ("Last 1 Hour", "Last 30 Minutes", etc.) with calendar icon and chevron
- [x] "Start Investigation" button styled with blue border and radar/scope icon
- [x] "Stop Investigation" button styled with soft red background/border and stop icon
- [x] Clicking "Start Investigation" activates high-detail observation via `EngineController.requestHighDetail` and smoothly transitions the view state

## Comments

## Notes (2026-10-13)

- Header baru `OverviewHeaderView`: judul "Overview" (.largeTitle), status live dari
  `evaluation.observation.mode` — normal (dot hijau), high-detail (spinner + sisa waktu),
  reduced (dot oranye + alasan). Status pill lama di DashboardView dihapus.
- "Start Investigation" memanggil `requestHighDetail(seconds: 1800)` (30 menit, sama seperti
  popover); "Stop Investigation" memanggil `Pipeline.endHighDetail()` yang baru — no-op saat
  tidak ada sesi, transisi "high-detail session ended early" tercatat seperti expiry alami.
- Time range picker (15m/30m/1h/6h/24h, default 1h) memakai enum `OverviewTimeRange` di engine
  agar ke-test; seleksi disimpan di DashboardView dan dikonsumsi tiket chart 03-04.
- Belum terverifikasi di Mac: `swift test` + tampilan header (tidak bisa build Swift di VM Linux).
