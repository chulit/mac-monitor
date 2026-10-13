# Spec: App Utama Processes Screen & Detail View

Status: ready-for-agent

## Problem Statement

Users need an honest, detailed view of all running processes on their Mac to identify which applications or background daemons are consuming resources. Existing tools often display cryptic process lists without showing parent-child hierarchy, separate individual process metrics from subtree aggregates, or link processes to historical resource curves and safe management controls. Furthermore, power users need a deep-dive process detail view showing execution path, bundle ID, thread counts, launch times, and real-time CPU/memory charts.

## Solution

A native macOS Processes interface featuring:
1. **Processes List View**:
   - Header with search filter, sort dropdown (`CPU ≘`), and live indicator badge (`• Live ⟳`).
   - 3 top summary stat cards: Total Processes count, CPU Usage with live sparkline, and Memory usage with live sparkline.
   - Comprehensive Process Table with an interactive "Show Process Tree" toggle.
   - Clean column layout: Process (icon + name + expand/collapse chevron), PID, CPU (numerical + blue progress bar), Memory, Parent Process, and action menu (`···`).
   - Status footer displaying total processes count and live update timestamp.
2. **Process Detail View**:
   - Header with back navigation, large application icon, application name, running badge (`● Running`), bundle metadata, and direct "Open in Finder" / action buttons.
   - Sub-navigation tabs: Overview, Performance, Threads, Files & Connections, Incidents.
   - 4 live metric stat cards: CPU Usage, Memory Usage, Disk Activity, Network Activity with smooth sparklines.
   - Dual historical timeline charts: CPU Usage ("Last 10 Minutes") and Memory Usage ("Last 10 Minutes").
   - 3-column information and action grid:
     - Process Information (Bundle ID, version, developer, launch time, PID, parent process, executable path).
     - Resource Usage Details (CPU usage, CPU time, threads, RSS, Virtual memory, open files, network read/write, disk read/write).
     - Actions (Show in Activity Monitor, Open Containing Folder, Create Exclusion, Terminate Process) and Related Processes (child processes list with PID and chevron navigation).

## User Stories

### Process List & Hierarchy
1. As a general user, I want to see the total number of running processes, overall CPU usage, and overall memory usage in clean stat cards at the top of the Processes screen.
2. As a productivity user, I want to search processes by name using a dedicated search bar, so that I can quickly find a specific app.
3. As a developer, I want to toggle between a flat list and a hierarchical process tree via "Show Process Tree", so that I can inspect parent-child relationships.
4. As a developer, I want to expand and collapse process groups with chevrons, so that I can see child helper processes under their main application.
5. As a power user, I want to sort the process list by CPU or Memory, so that top consumers appear at the top.
6. As a power user, I want to click any process row to open its comprehensive Process Detail screen.

### Process Detail & Metrics
7. As a developer, I want to see full process metadata (Bundle ID, developer, launch time, PID, parent PID, executable path), so that I can verify process identity safely.
8. As a power user, I want live metric cards for CPU, Memory, Disk, and Network with sparklines, so that I can see the app's current resource trajectory.
9. As a developer, I want dual side-by-side historical charts for CPU and Memory with time-range selectors, so that I can analyze past resource consumption.
10. As a power user, I want resource usage details including CPU time, thread count, RSS vs Virtual memory, open file count, and disk/network I/O rates.
11. As a general user, I want a safe "Terminate Process" action that confirms process identity before execution, preventing accidental termination of reused PIDs.
12. As a power user, I want to view and navigate to related child processes (e.g. Chrome Helpers) directly from the detail view.

## Implementation Decisions

- Builds upon `ProcessCollector`, `ProcessTreeRow`, and `ProcessSample` in `MonitoringEngine`.
- Process tree expansion state is maintained locally without triggering full engine re-evaluations.
- Process termination strictly enforces the two-confirmation safety protocol defined in ADRs and PRD FR-07.
- Smooth transitions between list view and detail view using standard navigation or sheet presentations.

## Testing Decisions

- Test process filtering, search matching, and tree expand/collapse behavior.
- Test that individual process metrics and subtree aggregates remain strictly separated.
- Test that process termination refuses execution when PID identity verification fails.

## Out of Scope

- Kernel extension injection or privileged daemon helpers.
- Force quitting system-critical processes protected by macOS SIP.
