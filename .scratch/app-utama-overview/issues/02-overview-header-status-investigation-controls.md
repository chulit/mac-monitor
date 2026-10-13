# 02: Overview header, monitoring status, and investigation controls

**What to build:** The header section of the Overview screen with dynamic monitoring status indicator, time range picker menu ("Last 1 Hour"), and "Start Investigation" / "Stop Investigation" toggle button hooked to engine high-detail mode.

**Blocked by:** 01 (navigation sidebar foundation).

**Status:** ready-for-agent

- [ ] Displays prominent "Overview" title conforming to macOS standard font sizes
- [ ] In normal state, displays green status indicator, "Monitoring Normal", and "All systems are running smoothly."
- [ ] In investigating state, displays active spinning indicator, "Investigating...", and diagnostic status subtitle
- [ ] Time range dropdown menu ("Last 1 Hour", "Last 30 Minutes", etc.) with calendar icon and chevron
- [ ] "Start Investigation" button styled with blue border and radar/scope icon
- [ ] "Stop Investigation" button styled with soft red background/border and stop icon
- [ ] Clicking "Start Investigation" activates high-detail observation via `EngineController.requestHighDetail` and smoothly transitions the view state

## Comments
