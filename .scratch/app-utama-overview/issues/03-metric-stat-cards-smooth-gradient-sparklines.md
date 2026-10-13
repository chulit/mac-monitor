# 03: Metric stat cards with smooth gradient sparklines

**What to build:** Row of 4 metric cards (CPU, Memory, Disk, Network) with SF Symbol badges, large percentage/rate values, baseline deviation delta badges during investigation, and smooth cubic bezier sparklines with color-matched vertical gradient fills.

**Blocked by:** 02 (header and state foundation).

**Status:** ready-for-agent

- [x] 4 cards rendered in an evenly spaced horizontal row with subtle borders, rounded corners (14pt), and elevation shadows
- [x] Card 1 (CPU): chip icon, blue theme, percentage readout
- [x] Card 2 (Memory): RAM icon, purple theme, percentage readout
- [x] Card 3 (Disk): hard drive icon, green theme, percentage readout
- [x] Card 4 (Network): Wi-Fi / network icon, sky blue theme, formatted throughput readout (e.g. "4 MB/s")
- [x] Smooth cubic bezier sparklines with line stroke and vertical gradient area fills matching the card theme color
- [x] When in investigation mode, displays red delta indicator badge (e.g. `↑ +24% from baseline`)

## Comments

## Notes (2026-10-13)

- `MetricStatCard` baru: chip icon badge, value besar, sparkline bezier, border 14pt + shadow.
- Sparkline kini memakai `smoothCurveSegments` (Catmull-Rom → cubic bezier) dari engine;
  math-nya UI-free dan unit-tested, view tinggal membangun Path.
- Delta badge memakai `baselineDeviation` (engine, tested): hanya tampil saat investigating
  dan baseline aktif; tanpa baseline yang usable tidak ada badge (tidak dikarang).
- `EngineController` mengekspos `baselineMeans` (hanya baseline aktif) dan `isInvestigating`;
  OverviewHeaderView memakai ulang flag yang sama.
- Belum terverifikasi di Mac: `swift test` + tampilan kartu (tidak bisa build Swift di VM Linux).
