# Spec: App Utama Overview Screen

Status: ready-for-agent

## Problem Statement

Mac users need a central, approachable overview screen that communicates system conditions at a glance without clutter. Existing system monitors either present overwhelming raw numbers, hide context behind deep sub-menus, or fail to connect live observations with incident alerts and on-demand high-detail investigation. When users experience performance pressure, they need an immediate way to initiate an investigation session, observe live findings in real time, and trace abnormal resource consumption back to specific processes and baseline deviations.

## Solution

A native macOS Overview screen adhering to Apple design principles that serves as the default landing view in Ultimate Mac Monitor. The overview displays:
1. A clear header showing monitoring status (e.g. "Monitoring Normal" or "Investigating...") with duration filters and a prominent "Start Investigation" / "Stop Investigation" action.
2. Four primary metric cards (CPU, Memory, Disk, Network) featuring live values, custom gradient sparkline curves, and contextual baseline deviation indicators when investigating.
3. An interactive multi-metric timeline chart with metric selection tabs (CPU, Memory, Disk, Network), custom scale gridlines, and interactive tooltip inspection.
4. When at rest: side-by-side cards for Recent Incidents (with severity badges, timestamps, and deep links) and Top Processes (with process icons, resource shares, and visual usage bars).
5. When in High-Detail Investigation Mode: a dedicated Investigation Progress card with a circular progress gauge (phases and completion percentage) and a multi-step phase progress tracker, accompanied by Live Findings and Preliminary Insights cards.

## User Stories

### High-level Overview & Monitoring Status
1. As a general user, I want to see the application branding and navigation in a sleek macOS sidebar, so that I can easily navigate between Overview, Processes, Incidents, History, and Settings.
2. As a general user, I want the sidebar Incidents tab to show a badge count of active incidents, so that I am immediately aware of detected anomalies.
3. As a general user, I want to see an honest monitoring status indicator ("Monitoring Normal" or "Reduced Monitoring") in the overview header, so that I understand whether observation is running cleanly.
4. As a general user, I want a time range selector (e.g. "Last 1 Hour") in the header, so that I can contextualize the data window being analyzed.

### Metric Stat Cards & Baseline Deviations
5. As a productivity user, I want four distinct metric cards for CPU, Memory, Disk, and Network, so that I can assess key system components simultaneously.
6. As a productivity user, I want each metric card to feature a color-coded sparkline with smooth gradient fills, so that I can visually register recent trend trajectories.
7. As a developer, I want metrics that are unavailable to be clearly reported as unavailable rather than coerced to zero, so that I am never misled by missing hardware telemetry.
8. As a power user, I want each card to display baseline deviation percentages (e.g. "↑ +24% from baseline") during investigation, so that I know how significantly the current state deviates from normal behavior.

### Interactive Usage Timeline
9. As a developer, I want an interactive chart showing metric history over time, so that I can observe spikes and sustained resource pressure.
10. As a developer, I want to switch the timeline view between CPU, Memory, Disk, and Network via segmented pill tabs, so that I can examine each subsystem independently.
11. As a power user, I want to hover over or scrub across the timeline curve to see a synchronized tooltip displaying the exact timestamp and percentage, so that I can pinpoint when an event occurred.
12. As a general user, I want the timeline grid lines and axes to format cleanly with human-readable timestamps and percentage scales, so that the data is easy to interpret.

### Incidents and Process Attribution
13. As a productivity user, I want a "Recent Incidents" section listing recent anomalies with severity color indicators, affected processes, and elapsed time, so that I can quickly spot notable events.
14. As a productivity user, I want a "See All" button on Recent Incidents that navigates directly to the Incidents section, so that I can review full incident packages.
15. As a power user, I want a "Top Processes" section ranking processes by CPU (or Memory), displaying process icons, names, exact percentages, and visual bars, so that I can spot heavy consumers immediately.
16. As a power user, I want to sort Top Processes using a dropdown selector (by CPU, by Memory), so that I can attribute resource pressure to the right processes.

### High-Detail Investigation Mode
17. As a productivity user noticing a slowdown, I want to click "Start Investigation" to initiate a high-detail investigation session, so that the engine increases sampling frequency and gathers granular telemetry.
18. As a general user, I want a clear progress card during investigation showing a circular donut gauge with phase completion percentage (e.g. 72%), so that I know investigation is actively underway.
19. As a developer, I want the investigation progress card to show the individual phases ("Scanning System Resources", "Analyzing Processes", "Detecting Potential Issues") with status indicators and elapsed durations, so that I can track diagnostic progress.
20. As a power user, I want to see a stream of "Live Findings" with timestamps as they are detected during the session, so that I have immediate visibility into emerging anomalies.
21. As a general user, I want a "Preliminary Insights" card summarizing evidence-based findings with descriptive context without jumping to unproven causal claims, so that I understand what the data indicates.
22. As a general user, I want an in-progress banner stating that final reports will be available upon completion, so that I know when findings are provisional.
23. As a productivity user, I want a prominent "Stop Investigation" button to end the high-detail session at any time, returning sampling to normal mode without waiting for the automatic timeout.

## Implementation Decisions

- **Architecture & Presentation Layer**:
  - The Overview screen is built in SwiftUI using native macOS materials, hierarchical typography, and fluid spring animations adhering to `/apple-design` guidelines.
  - The view renders from a unified model driven by `EngineController`, maintaining synchronous state between the live pipeline evaluation, host collector metrics, and UI presentation.
- **State Transition Machine**:
  - The view manages two primary visual states: `Normal` and `Investigating`.
  - Transitioning into `Investigating` requests high-detail observation via `EngineController.requestHighDetail(seconds:)` and animates the appearance of the investigation progress card, live findings, and preliminary insights, while metric cards display live baseline deviation tags.
  - Transitioning out of `Investigating` restores the normal monitoring header, hides provisional investigation cards, and displays the standard Recent Incidents and Top Processes panels.
- **Visual Design Tokens & Components**:
  - Native sidebar navigation with custom `AppSection` enum items (`overview`, `processes`, `incidents`, `history`, `settings`) and red incident badge.
  - Metric cards designed with subtle border outlines (`Color.primary.opacity(0.06)`), rounded corners (12pt), and custom gradient sparkline area paths.
  - Smooth Bezier line chart for the usage history with selectable metric tabs, subtle grid lines, and interactive hover tooltip inspection.
  - Reusable Apple-style progress indicators, steppers, and pill buttons.
- **Process & Incident Attribution**:
  - Top processes integrate with `processCollector` deltas and `ProcessSample` metadata to display genuine running applications (e.g., WindowServer, kernel_task, browsers) with accurate proportional bars.
  - Recent incidents hook into pipeline incidents, formatting timestamps relative to current clock time.

## Testing Decisions

- **Seams & External Behavior**:
  - Testing focuses on the presentation model and state transitions crossing the existing sampling seam and engine controller:
    1. Verifying that toggling investigation mode triggers high-detail sampling requests with appropriate duration limits.
    2. Verifying that metric card values and history sparklines reflect incoming available samples without zero-filling gaps.
    3. Verifying that baseline deviation tags calculate correctly from baseline status and current sample value.
    4. Verifying that phase progress transitions from scanning to analyzing to issue detection accurately.
- **Prior Art**:
  - Follows established test patterns in `Tests/MonitoringEngineTests/SamplingSeamTests.swift`.

## Out of Scope

- Remote cloud synchronization or telemetry uploads (strict local-first principle).
- Automatic termination of background processes without user consent.
- Modifying underlying kernel task parameters or injecting helper daemons.

## Further Notes

- The design strictly matches `a. overview.png` (for normal monitoring state) and `b. overview - start-investigating.png` (for high-detail investigation state).
- Designed for macOS 13+ with support for light and dark appearance using dynamic semantic system colors.
