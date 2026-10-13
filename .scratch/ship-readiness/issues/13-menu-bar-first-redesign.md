# 13: Menu-bar-first redesign with sidebar navigation

**What to build:** the menu-bar popover becomes the primary interface and the full window uses sidebar navigation, replacing the tutorial-looking tabbed window.

**Blocked by:** 11 (Menu bar extra with live readout).

**Status:** ready-for-agent

- [x] Status-item click opens a popover with condensed status, not just a percentage menu
- [x] The full window uses sidebar navigation across the three existing screens
- [x] Views stay thin with no new test seam

## Comments

- Screenshot-driven fixes on the dashboard: sparklines use an adaptive Y-domain (fixed 0–1 rendered flat lines glued to the top edge); the view is a top-aligned ScrollView so empty states no longer stretch across the window; empty Incidents/Notices sections are omitted instead of listed; storage reads humanized ("54 samples · quota 150.0M").
