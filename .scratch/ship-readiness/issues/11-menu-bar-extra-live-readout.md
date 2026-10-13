# 11: Menu bar extra with live readout

**What to build:** the app lives in the menu bar (no Dock icon) with a live CPU readout, opening the monitor windows on demand.

**Blocked by:** 04 (App target with live dashboard).

**Status:** ready-for-agent

- [x] `LSUIElement` is set: no Dock icon, presence is menu-bar-only
- [x] The status item shows the latest CPU share, honestly blank before the first reading
- [x] The menu offers opening the monitor windows and quitting; views stay thin with no new test seam

## Comments

- `AppDelegate` owns the status item and renders only the latest CPU share ("–" before the first reading); Open Monitor brings the windows forward, Quit terminates. No Dock icon anymore.
- Verified by warning-free build plus the untouched engine suite (no UI seam, per agreement).
