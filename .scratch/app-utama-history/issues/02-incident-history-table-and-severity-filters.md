# 02: Incident history table and severity filter pills

**What to build:** The Incident History card in the History screen with severity filter tabs (`[ All | High | Medium | Low ]`), sort dropdown, list/grid toggle, and multi-column table.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] Filter pill selector switching between `All`, `High`, `Medium`, and `Low`
- [x] Sort dropdown button ("Newest First ∨") and view mode switch (Table / Grid)
- [x] Table columns: `Time`, `Type`, `Title`, `Affected Processes`, `Peak Value`, `Duration`, `Status` (Active/Resolved), and navigation chevron
- [x] Clicking any row navigates to the History Detail view

## Comments

## Notes (2026-10-14)

- Severity = intensitas peak selama insiden (≥90% High, ≥70% Medium);
  engine tidak menyimpan label severity.
- Affected Processes "—" untuk insiden lama (atribusi tak tersimpan).
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
