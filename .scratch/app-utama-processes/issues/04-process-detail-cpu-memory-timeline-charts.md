# 04: Process detail CPU and Memory historical timeline charts

**What to build:** Side-by-side historical timeline charts for CPU Usage and Memory Usage with time-range selectors in the Process Detail screen.

**Blocked by:** 03 (process detail foundation).

**Status:** ready-for-agent

- [x] Left card: CPU Usage chart with header, time-range dropdown ("Last 10 Minutes ∨"), Y-axis percentage labels (0% to 100%), gridlines, and smooth blue curve with gradient fill
- [x] Right card: Memory Usage chart with header, time-range dropdown ("Last 10 Minutes ∨"), Y-axis memory capacity labels (0 to 4 GB), gridlines, and smooth purple curve with gradient fill
- [x] X-axis timestamps formatted across both charts (e.g. 09:10, 09:12, 09:14, 09:16, 09:18, 09:20)

## Comments

## Notes (2026-10-14)

- Grafik CPU memakai riwayat yang dikumpulkan jujur selama detail dibuka
  (1/5/10 menit terakhir). Grafik memori menampilkan empty state yang
  jujur: tidak ada data memori per proses.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
