# 07: Settings Privacy & Security and About sub-panels

**What to build:** The Privacy & Security sub-panel (`F. Settings - Privacy & Security.png`) and About sub-panel (`G. Settings - About.png`).

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] **Privacy & Security Panel**:
  - Permissions card: System Monitoring (`Granted`), Sensor Access (`Granted`), Process Information (`Granted`)
  - Data Privacy card: Anonymous Usage Data, Crash Reports, Include System Information
  - Security card: Require Password, Hide Sensitive Information (hides process names and file paths in exports/screenshots)
  - Reset & Clear Data card: "Clear All Data" action button
- [x] **About Panel**:
  - Header: App icon, Ultimate Mac Monitor title, Version (1.2.0), "● Up to date" badge, "Check for Updates", "View on GitHub ↗"
  - What's New card: Changelog list (v1.2.0, v1.1.0, v1.0.0) with "View All Updates >"
  - Links card: Documentation, GitHub Repository, Report an Issue, Give a Star
  - System Info card: macOS version, Chip type, Memory, and Model specifications

## Comments

## Catatan implementasi
- "Require Password" dihilangkan: tidak ada implementasi app-lock;
  kontrol keamanan palsu lebih buruk daripada tidak ada.
- "Anonymous Usage Data"/"Crash Reports" disimpan sebagai preferensi
  dengan footnote jujur: tidak ada telemetri yang dikirim di versi ini.
- Versi/changelog/system info semuanya dari sistem asli (Bundle, sysctl).
- "Hide Sensitive Information" nyata: dipakai saat Share Incident export.
