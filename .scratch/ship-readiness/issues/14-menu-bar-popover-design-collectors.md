# 14: Menu-bar popover per design with disk and network collectors

**What to build:** the menu-bar popover from `docs/plans/design/1. menu-bar`, fed by real collectors where they exist and honest unavailable states where they don't.

**Blocked by:** 11 (Menu bar extra with live readout).

**Status:** ready-for-agent

- [x] Disk usage and network throughput collectors join the sampling seam unprivileged
- [x] The popover matches the design structure: header, metric cards, incidents, monitoring mode, action row
- [x] Monitoring-mode cards reflect live state; the high-detail button starts a real 30-minute session
- [x] Menu-bar items show live CPU, memory, disk, and network; temperature stays honestly unavailable
- [x] Follow-up recorded: temperature/per-component sensor research (SMC, model-specific)

## Comments

- Delivered against `docs/plans/design/1. menu-bar`, with deliberate deviations recorded: no settings gear (no settings screens exist — no fake affordances), session button is 10 minutes per the decided cap (not the mockup's 30), and System Health opens the investigation section (incidents are our honest reading of that label).
- Temperature card renders an explicit unavailable state; the per-component detail section is omitted entirely until ticket 15 lands. Nothing is fabricated to fill the mockup's boxes.
- Four live menu-bar items (CPU, memory, disk, network rate); deep links route each action button to its sidebar section.
