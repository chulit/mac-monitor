# 04: History detail timeline chart and primary process details

**What to build:** The CPU Usage Timeline card (with shaded incident period) and the Process Details card in the History Detail screen.

**Blocked by:** 03.

**Status:** ready-for-agent

- [x] "CPU Usage Timeline" card displaying the metric trajectory with a highlighted shaded "Incident Period", legend indicator, and data point tooltip (`Apr 28, 10:13 • CPU 92%`)
- [x] "Process Details" card displaying primary responsible application metadata (app icon, name, path, PID, peak CPU, average CPU, memory usage, start time, and "Open in Activity Monitor ↗" link)

## Comments

## Notes (2026-10-14)

- Timeline memakai ulang `IncidentTimelineChart` via `historicalTimeline`.
- Process Details hanya terisi untuk insiden recent (timeline live);
  path/memori/start time "—" karena tak dikumpulkan engine.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
