# 05: Recent incidents and top processes cards

**What to build:** Bottom split row for normal monitoring state: "Recent Incidents" card with categorized anomaly badges, timestamps, and deep links; and "Top Processes" card with application icons, names, percentage shares, sort menu ("by CPU"), proportional progress bars, and navigation links.

**Blocked by:** 04 (timeline chart).

**Status:** ready-for-agent

- [x] "Recent Incidents" card with header and "See All >" link that navigates to the Incidents section
- [x] Incident items display categorized colored badge (flame for CPU, leaf/warning for Memory, waveform for Network), anomaly title, responsible process subtitle, relative time, and chevron
- [x] "Top Processes" card with header and "by CPU / by Memory" sort dropdown
- [x] Top process rows display recognizable application icon, process name, percentage readout (e.g. "24,3%"), proportional horizontal blue progress bar, and trailing chevron
- [x] Cards have unified card corner radius (14pt), borders, and spacing matching the mockup

## Comments

## Notes (2026-10-13)

- Engine (`OverviewCards.swift`): `IncidentCategory`, `incidentTitle`,
  `relativeTimeString`, dan `topProcesses` (sampel terbaru per proses,
  urut share, clamp 0...1) — semuanya pure dan unit-tested.
- PopoverView kini memakai fungsi engine yang sama (hapus duplikasi
  `incidentTitle`/`relativeTime` privat).
- Ikon aplikasi asli via `NSRunningApplication(processIdentifier:)`; fallback
  glyph generik bila proses sudah hilang.
- Persentase memakai NumberFormatter `.percent` (locale-aware: "24,3%" di ID).
- Navigasi: kartu menerima closure `onNavigate` yang sempit (bukan seluruh
  store); "See All" dan baris menuju section Incidents/Processes.
- Belum terverifikasi di Mac: `swift test` + tampilan kartu (tidak bisa build
  Swift di VM Linux).
