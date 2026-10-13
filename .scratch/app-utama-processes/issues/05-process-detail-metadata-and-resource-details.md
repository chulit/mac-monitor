# 05: Process information and resource usage details

**What to build:** The Process Information card and Resource Usage Details card in the Process Detail screen.

**Blocked by:** 03 (process detail foundation).

**Status:** ready-for-agent

- [x] "Process Information" card displaying metadata: Process Name, Bundle ID, Version, Developer, Launch Time, Process ID (PID), Parent Process, and Executable Path
- [x] "Resource Usage Details" card displaying telemetry: CPU Usage, CPU Time, Thread count, Memory (RSS), Memory (Virtual), Open Files count, Network Read, Network Write, Disk Read, Disk Write
- [x] Clean typographic alignment with icons and secondary label colors

## Comments

## Notes (2026-10-14)

- Hanya CPU Usage yang real; sisanya "—" dengan catatan kaki yang jujur.
  Tidak ada angka telemetri yang difabrikasi.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
