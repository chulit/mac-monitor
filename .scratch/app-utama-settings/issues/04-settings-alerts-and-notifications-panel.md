# 04: Settings Alert & Notifications sub-panel

**What to build:** The Alert & Notifications settings sub-panel (`C. Settings - Alert & Notifications.png`) including channels, threshold sliders, and alert types.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] "Enable Notifications" master toggle card
- [x] "Alert Channels" card with toggles: macOS Notifications, Sound, Badge on Menu Bar
- [x] "Alert Thresholds" card with individual sliders and "Reset to Default" button:
  - CPU Usage (85%)
  - Memory Usage (85%)
  - Disk Usage (90%)
  - Network Usage (100 MB/s)
  - Temperature (85 °C)
- [x] "Alert Types" card with checkboxes: High CPU Usage, High Memory Usage, High Disk Usage, Unusual Network Activity, High Temperature, App Not Responding

## Comments

## Catatan implementasi
- "Badge on Menu Bar" diimplementasikan sebagai badge di Dock
  (tidak ada menu-bar UI) dengan label jujur "Badge on Dock".
- Threshold Network/Temperature disimpan untuk detektor masa depan;
  hanya CPU/Memory/Disk yang memicu incident hari ini (ada caption di UI).
- "App Not Responding" belum dideteksi engine; toggle-nya disimpan.
