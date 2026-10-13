# 05: Incident timeline plus process tree screens

**What to build:** investigation screens consuming the timeline and process-row view state.

**Blocked by:** 02 (Process enumeration with stable identity tokens), 04 (App target with live dashboard).

**Status:** ready-for-agent

- [x] The incident screen renders synchronized timeline points, tooltips, and provenance from view state
- [x] The process screen renders rows with separate aggregates plus expand, collapse, and search
- [x] Same UI-seam flag as ticket 04: seam confirmed before TDD

## Comments

- Built per the confirmed thin-screens decision: `TimelineView` renders points, relevance, and the evidence-graded explanation; `ProcessTreeView` owns only search/expand UI state over `processRows`. No new test seam; verification is a warning-free build plus the untouched 60-test engine suite.
