# 02: Processes table with tree hierarchy toggle

**What to build:** The main process table with "Show Process Tree" toggle, column headers, row rendering with app icons, expandable parent-child rows, CPU progress bars, and footer counter.

**Blocked by:** 01 (header & summary foundation).

**Status:** ready-for-agent

- [x] "Show Process Tree" toggle switch switching between flat list and parent-child tree hierarchy
- [x] Table columns: `Process`, `PID`, `CPU`, `Memory`, `Parent Process`, and actions `···`
- [x] Process column renders app/system icon, process name, and expandable disclosure chevron for parent processes
- [x] CPU column renders exact percentage (e.g. 24.3%) and proportional horizontal blue progress bar
- [x] Clicking any row selects and navigates to the Process Detail screen
- [x] Footer counter showing total processes count and live update status (e.g. "184 processes · Updated just now")

## Comments

## Notes (2026-10-14)

- Kolom Memory menampilkan "—": engine hanya mengumpulkan CPU per proses.
  Tidak ada angka yang difabrikasi.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
