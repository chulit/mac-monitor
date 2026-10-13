# Spec: App Utama History Screen & History Detail View

Status: ready-for-agent

## Problem Statement

Users need historical visibility over their Mac's performance trends and past incidents without boundless disk usage or lost context. Standard tools either drop data after a reboot or retain unorganized log dumps. Users need an aggregated view of multi-day system activity and an incident history log that can be filtered by severity and searched, with deep-dive detail into each historical occurrence.

## Solution

A native macOS History interface featuring:
1. **Main History Screen**:
   - Header with title, subtitle, date range dropdown ("Last 7 Days"), and search input ("Search history...").
   - **System Activity Card**: multi-day trend graph with metric tabs (`[ CPU | Memory | Disk | Network | Temperature ]`), interactive scrubber tooltip, and daily timestamp markers.
   - **Incident History Card**: filter pills (`[ All | High | Medium | Low ]`), sort dropdown ("Newest First"), list/grid view toggle, and comprehensive table (Time, Type, Title, Affected Processes, Peak Value, Duration, Status badge, and navigation chevron).
2. **History Detail Screen**:
   - Header with back navigation, incident badge, title, timestamp/duration, and status badge.
   - Overview card: Time, Duration, Peak value, Affected Processes, Status, and narrative description.
   - Timeline card: historical metric graph around the incident with shaded "Incident Period" and peak data point tooltip.
   - Affected Processes table: detailed breakdown of processes with peak and average resource consumption.
   - Process Details card: deep metadata for the primary process with path, PID, and "Open in Activity Monitor" shortcut.
   - System Context card: auxiliary subsystem context during the incident (Memory, Disk, Network).
   - Actions card: "View Related Processes", "Create Exclusion", and "Share Incident" (export package).

## User Stories

### Main History Overview
1. As a general user, I want to see a multi-day trend of my system's resource usage across CPU, Memory, Disk, Network, and Temperature.
2. As a power user, I want to filter the incident history table by severity (`All`, `High`, `Medium`, `Low`) to review critical events.
3. As a developer, I want to search past incidents by keyword using the search bar.
4. As a user, I want clicking any row in the Incident History table to open the detailed History Detail view.

### History Detail Investigation
5. As a developer, I want to see the exact time span and duration of a historical incident alongside a descriptive explanation.
6. As a power user, I want to inspect the timeline curve around the historical incident with a clearly marked incident window.
7. As a developer, I want to inspect the system context (auxiliary memory pressure, disk activity, network throughput) at the time the incident occurred.
8. As a user, I want to share or export the historical incident using "Share Incident".

## Implementation Decisions

- Integrates with the storage retention policy in `MonitoringEngine` (retaining full samples for recent data and compact summaries for older spans).
- Historical charts format daily and hourly axes gracefully.
- "Share Incident" bridges to the incident package export workflow per PRD FR-11.

## Testing Decisions

- Test that time-range changes update both the System Activity curve and the Incident History table.
- Test that severity filters accurately segment incidents.
- Test that opening a historical incident correctly preserves and displays its recorded context.

## Out of Scope

- Cloud backups or remote analytics.
