# 05: Incident detail related processes attribution table

**What to build:** The "Related Processes" table in the incident detail pane displaying processes ranked by measured contribution to the incident.

**Blocked by:** 03.

**Status:** ready-for-agent

- [x] "Related Processes" table header with columns: `Process`, `CPU ≘`, `Memory`, `Parent Process`, and action menu `···`
- [x] Rows display app icon, process name, percentage (e.g. 68.2%), red proportional usage progress bar, memory size (e.g. 612 MB), and parent process name (e.g. _windowserver, launchd)
- [x] Process relevance is clearly communicated based on measured usage during the incident span

## Comments

## Notes (2026-10-14)

- Kolom Memory "—": tidak ada memori per proses di engine. Bar merah
  proporsional terhadap kontribusi maksimum.
- Catatan kaki korelasi-vs-kausasi sesuai spec.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
