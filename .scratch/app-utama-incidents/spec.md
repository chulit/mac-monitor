# Spec: App Utama Incidents Screen & Detail Investigation

Status: ready-for-agent

## Problem Statement

When system anomalies occur, users need a dedicated Incidents center to review detected conditions, examine synchronized telemetry along a timeline, and understand process attribution with evidence. Existing tools separate notifications from historical evidence and never show the progression of an incident from start to peak to recovery.

## Solution

A native macOS split-view Incidents screen featuring:
1. **Left Panel: Incident List**:
   - Header with title, subtitle, filter tabs (`[ All | Active | Resolved ]`), and time range selector ("Last 7 Days").
   - Categorized incident items with colored anomaly icons (High CPU, Memory Pressure, Network Activity, Disk Spike, High Temperature, Crashes, App Not Responding).
   - Real-time status badges (`Active` in red pill, `Resolved` in subtle gray pill), responsible processes, and relative timestamps.
2. **Right Panel: Incident Detail**:
   - Incident Header with icon badge, incident title, status badge, action menu (`···`), and duration metadata.
   - Summary Statistics: Peak CPU, Average CPU, Duration, Affected Processes count.
   - Synchronized Multi-Metric Timeline Chart: metric selector tabs (`CPU`, `Memory`, `Disk`, `Network`, `Temperature`), shaded incident span, and peak tooltip marker.
   - Related Processes Table: processes ranked by contribution, showing CPU usage, red proportional usage bars, memory footprints, and parent processes.
   - Timeline Event Trail: chronological vertical event sequence marking detection, metric escalations, related process activity, and current status.

## User Stories

### Incident List & Filtering
1. As a general user, I want to see all detected incidents in an organized list with clear visual severity indicators.
2. As a productivity user, I want to filter incidents by status (`All`, `Active`, `Resolved`), so that I can focus on current problems.
3. As a power user, I want to filter incidents by date range (e.g. "Last 7 Days"), so that I can investigate past events.
4. As a user, I want clicking any incident in the list to immediately populate the right detail pane.

### Incident Detail, Timeline & Attribution
5. As a developer, I want to see summary metrics (peak value, average value, total duration, affected process count) at the top of the detail pane.
6. As a developer, I want an interactive timeline chart showing the metric curve before, during, and after the incident with a highlighted incident span.
7. As a power user, I want to switch between CPU, Memory, Disk, Network, and Temperature tabs on the timeline chart.
8. As a developer, I want a Related Processes table ranking processes by measured contribution with proportional usage bars.
9. As a general user, I want a chronological event trail showing when the anomaly started, which processes increased usage, and whether it is resolved.

## Implementation Decisions

- Built using SwiftUI split view (`NavigationSplitView` or custom master-detail layout) matching `incidents.png`.
- Incidents bind to `Pipeline.evaluate` incident records and `Notice` models.
- Process attribution clearly separates correlation from causation, stating measured relevance reasons.

## Testing Decisions

- Test that incident filtering by `All`, `Active`, and `Resolved` displays the correct subset of incidents.
- Test that selecting an incident updates the right detail pane with accurate timestamps and process rankings.
- Test that timeline event markers synchronize with the metric graph time axis.

## Out of Scope

- Remote cloud syncing of incident records.
- Automatic termination of processes without explicit user confirmation.
