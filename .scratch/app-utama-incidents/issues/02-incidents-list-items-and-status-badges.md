# 02: Incidents list items and status badges

**What to build:** The scrollable list of incidents on the left panel with categorized anomaly badges, titles, responsible processes, relative timestamps, and active/resolved status tags.

**Blocked by:** 01.

**Status:** ready-for-agent

- [ ] Render incident cards with category icon badges:
  - High CPU Usage (flame icon, red)
  - Memory Pressure (leaf/warning icon, orange)
  - Unusual Network Activity (pulse icon, blue)
  - Disk Activity Spike (hard drive icon, gray)
  - High Temperature (thermometer icon, orange)
  - Repeated App Crashes (crash/wave icon, blue)
  - App Not Responding (exclamation icon, amber)
- [ ] Status pill badges: `Active` in red pill and `Resolved` in subtle gray pill
- [ ] Relative timestamps (e.g. "2m ago", "1h ago") and trailing chevron
- [ ] Selecting an incident highlights the card and loads its detail into the right panel

## Comments
