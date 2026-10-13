# 12: Interface polish pass

**What to build:** the three screens look and feel like a real Mac app: visual hierarchy, charts, and readable numbers instead of raw debug lists.

**Blocked by:** 05 (Incident timeline plus process tree screens).

**Status:** ready-for-agent

- [x] Dashboard leads with status and stat cards with sparklines, not raw lists
- [x] The investigation screen charts metrics with incident markers, keeping evidence detail below
- [x] Numbers use tabular figures and consistent formatting; views stay thin with no new test seam

## Comments

- Dashboard: status pill, CPU/memory stat cards with area sparklines over a 120-reading rolling history, then incidents/baselines/storage/notices. Investigation: Swift Charts series per metric with start/peak/recovered rule marks above the tooltip detail, relevance, and explanation. Processes: chevrons, proportion bars, and individual-vs-subtree figures.
- Views still contain no logic beyond view-state calls plus display-local UI state; verification is a warning-free build plus the untouched engine suite.
