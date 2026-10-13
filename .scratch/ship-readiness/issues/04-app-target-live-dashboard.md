# 04: App target with live dashboard

**What to build:** a macOS app target rendering the dashboard view state with live data.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam).

**Status:** ready-for-agent

- [x] A macOS app target exists and consumes the dashboard snapshot types directly
- [x] The dashboard renders live data with the simple-at-rest hierarchy from the view state
- [x] UI testing seam confirmed before TDD (no unilateral seams); engine suite stays green

## Comments

- Built per the confirmed thin-screens decision: `UltimateMacMonitorApp` target with an `EngineController` owning the pipeline and both collectors on a 1s timer, and a `DashboardView` that only renders `makeDashboard` output. No new test seam; verification is a warning-free build plus the untouched 60-test engine suite.
- Detection numbers in the app are provisional placeholders explicitly marked pending Ship-07.
