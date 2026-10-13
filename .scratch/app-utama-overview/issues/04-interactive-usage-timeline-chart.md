# 04: Interactive usage timeline chart

**What to build:** Full-width interactive usage timeline card for normal monitoring state, featuring metric selector pill tabs (CPU, Memory, Disk, Network), custom Y-axis gridlines (0%-100%), X-axis timestamp labels, smooth bezier area curve, and interactive inspection tooltip with hairline marker.

**Blocked by:** 03 (metric cards).

**Status:** ready-for-agent

- [x] Header shows active metric title (e.g. "CPU Usage") and segmented pill selector `[ CPU | Memory | Disk | Network ]`
- [x] Switching tabs updates the curve, gradient area fill, and active theme color
- [x] Y-axis displays percentages (100%, 75%, 50%, 25%, 0%) with subtle horizontal gridlines across the chart
- [x] X-axis displays synchronized time markers (e.g. 09:20, 09:30, 09:40, 09:50, 10:00, 10:10)
- [x] Interactive inspection tooltip showing timestamp (e.g. "10:00:14") and metric reading (e.g. "• CPU 68%") with a vertical guideline and data point circle

## Comments

## Notes (2026-10-13)

- Ditulis dengan panduan kedua skill SwiftUI yang baru dipasang (swiftui-pro +
  swiftui-expert-skill): TimelinePlot adalah tipe View tersendiri dengan input
  `let` yang sempit (invalidation boundary), @State private, DateFormatter
  static, tanpa kerja berat di body, label aksesibilitas ringkas untuk chart,
  dan styling kartu diekstrak ke `DashboardCardStyle` ViewModifier.
- Engine (`TimelineChart.swift`): `TimelineMetric`, `yAxisTicks` (persen tetap
  untuk CPU/Memory/Disk; nice-ceiling + formatRate untuk Network),
  `timeAxisMarkers`, `samples(in:endingAt:from:)` (filter jujur tanpa
  interpolasi), `nearestSample` (selalu sampel asli). `OverviewTimeRange.label`
  untuk frasa durasi.
- Chart memakai rentang waktu pilihan dari header issue 02 (15m–24h).
- Tooltip: timestamp HH:mm:ss + "• CPU 68%" / "• Network 4.2 MB/s", guideline
  vertikal + titik, hilang saat drag selesai.
- Belum terverifikasi di Mac: `swift test` + interaksi scrub (tidak bisa build
  Swift di VM Linux).
