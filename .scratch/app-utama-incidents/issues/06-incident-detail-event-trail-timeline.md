# 06: Incident detail event trail timeline

**What to build:** The chronological event trail timeline in the incident detail pane displaying key milestones of the anomaly.

**Blocked by:** 03.

**Status:** ready-for-agent

- [x] Vertical event trail with connecting lines and circular milestone markers
- [x] Displays timestamps and narrative events:
  - Detection event: e.g. "10:13 — High CPU usage detected (CPU 92%)"
  - Escalation event: e.g. "10:13 — WindowServer CPU increased from 28% to 92%"
  - Related process event: e.g. "10:14 — Related process: screencapture (12.6%)"
  - Status marker: e.g. "10:15 — Still ongoing..." or recovery marker
- [x] Markers styled cleanly matching Apple design aesthetics

## Comments

## Notes (2026-10-14)

- Trail hanya dari catatan bertimestamp asli: marker started/peak/
  recovered + transisi observasi. Atribusi proses tidak punya timestamp
  per-event sehingga tetap di tabel Related Processes (tidak difabrikasi).
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
