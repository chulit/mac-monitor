# 04: App target with live dashboard

**What to build:** a macOS app target rendering the dashboard view state with live data.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam).

**Status:** ready-for-agent

- [ ] A macOS app target exists and consumes the dashboard snapshot types directly
- [ ] The dashboard renders live data with the simple-at-rest hierarchy from the view state
- [ ] UI testing seam confirmed before TDD (no unilateral seams); engine suite stays green
