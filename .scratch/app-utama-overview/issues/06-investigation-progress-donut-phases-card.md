# 06: Investigation progress donut gauge and phase tracker card

**What to build:** The dedicated Investigation Progress card displayed during active investigation session, containing a circular progress donut gauge and a 3-step vertical diagnostic phase tracker.

**Blocked by:** 02 (header and investigation state toggle).

**Status:** ready-for-agent

- [x] Prominent circular progress donut gauge with blue stroke (~72% filled), central "72%" percentage, "Investigating" label, and "2 of 3 phases" counter
- [x] 3-step vertical diagnostic phase tracker with vertical alignment and custom step states:
  - Step 1: "Scanning System Resources" — completed badge with checkmark, duration "Completed 12s"
  - Step 2: "Analyzing Processes" — active target icon, duration "72% 18s", and horizontal progress bar
  - Step 3: "Detecting Potential Issues" — pending gray ring, duration "Pending —"
- [x] Card layout matches `b. overview - start-investigating.png` with smooth spring animation on entrance and exit

## Comments

## Notes (2026-10-13)

- Engine (`InvestigationProgress.swift`): fraksi sesi asli (elapsed/limit dari
  `ObservationMode.highDetail`), tiga fase dengan state dari fakta — scanning
  completed saat koleksi berjalan, analyzing aktif sepanjang sesi (persen dan
  detik real), detecting completed hanya bila insiden bermula di dalam sesi.
  Tidak ada angka karangan; durasi fase 1 yang tak terukur memakai "—".
- `SlimProgressBar` diekstrak sebagai view shared (dipakai TopProcessesCard
  dan tracker fase).
- Kartu hanya tampil saat investigating; spring animation saat muncul/hilang.
- Belum terverifikasi di Mac: `swift test` + tampilan kartu dan animasi
  (tidak bisa build Swift di VM Linux).
