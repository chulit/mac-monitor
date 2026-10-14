# 02: Settings General sub-panel

**What to build:** The General settings sub-panel (`A. Settings - General.png`) including App Behavior, Monitoring Mode, Resource Limits, and Reset.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] "App Behavior" card with toggles: Launch at login, Check for updates automatically, and Language selector ("English")
  - "Show in menu bar" DIIHILANGKAN (wontfix): app ini WindowGroup tanpa menu-bar UI; toggle-nya tidak bisa jujur.
- [x] "Monitoring Mode" card with selectable mode boxes: Normal (balanced), Reduced (lower overhead), and High Detail (more data for investigation)
- [x] "Resource Limits" card with sliders: Max CPU Usage (10%) and Max Memory Usage (500 MB)
- [x] "Reset" card with "Reset to Default" button

## Comments

## Catatan implementasi
- "Show in menu bar" dihilangkan: app ini WindowGroup tanpa menu-bar UI,
  toggle-nya tidak bisa jujur. Bukan dead control.
- "Max Memory Usage" disimpan sebagai preferensi; belum ada mekanisme
  enforce di engine — ada caption "Not enforced yet" di UI.
- "Check for updates automatically" nyata: memicu UpdateChecker
  (GitHub releases API) saat app start.
