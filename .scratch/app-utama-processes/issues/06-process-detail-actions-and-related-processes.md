# 06: Process control actions and related processes navigation

**What to build:** The Actions card (with safe termination flow) and Related Processes card in the Process Detail screen.

**Blocked by:** 05.

**Status:** ready-for-agent

- [x] "Actions" card with action buttons:
  - "Show in Activity Monitor ↗"
  - "Open Containing Folder ↗"
  - "Create Exclusion"
  - "Terminate Process" (highlighted red button with stop icon)
- [x] Safe process termination flow with confirmation modal verifying process identity before execution
- [x] "Related Processes" card listing child processes (e.g. Chrome Helpers) with app icons, names, PIDs, and interactive navigation chevrons

## Comments

## Notes (2026-10-14)

- Terminate memakai ProcessControl engine + DarwinProcessExecutor
  (token identitas dari libproc, protokol dua konfirmasi, deteksi PID reuse).
- "Create Exclusion" menampilkan alert jujur: belum diimplementasikan
  (tidak ada dukungan engine).
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
