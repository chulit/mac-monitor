# Spec: App Utama Settings Screen & Sub-Panels

Status: ready-for-agent

## Problem Statement

Users need a comprehensive, modular Settings center to configure application preferences, monitoring sampling intervals, resource budgets, alert channels, storage retention policies, appearance themes, privacy controls, and view application build info. Existing tools often hide settings in nested modals or lack transparency about data collection and resource consumption.

## Solution

A native macOS two-column Settings interface featuring:
1. **Left Settings Navigation Column**:
   - Clean list of 7 settings categories with icons:
     - General (`gearshape.fill`)
     - Monitoring (`waveform.path.ecg`)
     - Alerts & Notifications (`bell.fill`)
     - Data & Storage (`cylinder.split.1x2.fill` / storage icon)
     - Appearance (`display`)
     - Privacy & Security (`lock.shield.fill`)
     - About (`info.circle.fill`)
2. **Right Content Panel**:
   - Dynamically displays the selected category's settings conforming to Apple design standards:
     - **General**: App behavior toggles, monitoring mode selector, resource limits sliders, and reset button.
     - **Monitoring**: Sampling intervals per metric, monitored metrics toggles, and resource caps.
     - **Alerts & Notifications**: Notification channels, threshold sliders, and anomaly alert type checkboxes.
     - **Data & Storage**: Retention policy selector (7, 30, 90 days, Custom), storage breakdown bar, and disk cleanup buttons.
     - **Appearance**: Light/Dark/Auto theme picker, accent color palette, interface density, sidebar options, and reduce motion toggle.
     - **Privacy & Security**: macOS permission statuses, local telemetry toggles, hide sensitive metadata toggle, and clear data button.
     - **About**: App logo, version status, update checker, GitHub link, release changelog notes, support links, and hardware system info card.

## User Stories

### General & Monitoring Settings
1. As a general user, I want toggles for "Launch at login", "Show in menu bar", and "Check for updates automatically".
2. As a power user, I want to switch between Normal, Reduced, and High Detail monitoring modes.
3. As a developer, I want to configure per-metric sampling intervals (CPU, Memory, Disk, Network, Temperature) and toggle specific metric collectors on or off.
4. As a performance-conscious user, I want to set maximum CPU and memory usage limits for the monitoring process itself.

### Alerts & Storage Settings
5. As a productivity user, I want to enable or disable notification channels (macOS notifications, sound, menu bar badge).
6. As a developer, I want to customize alert thresholds for each metric (e.g. CPU > 85%, Disk > 90%).
7. As a power user, I want to see a storage usage breakdown (Metrics, Incidents, Logs, Cache) and choose retention periods (7, 30, 90 days).
8. As a user, I want quick actions to "Clear History", "Clear Cache", or "Open Data Folder".

### Appearance, Privacy & About
9. As a user, I want to select between Light, Dark, and Auto themes, choose custom accent colors, and adjust interface density.
10. As a privacy-conscious user, I want to verify granted macOS permissions and toggle "Hide Sensitive Information" in exports/screenshots.
11. As a user, I want an About panel showing app version, changelog updates, and current Mac hardware specifications.

## Implementation Decisions

- Settings state is backed by `UserDefaults` with reactive publishers that automatically update `EngineController` and presentation layers.
- Metric toggles dynamically inform `ObservationPolicy` and collectors.
- All layouts use standard macOS grouped container cards with rounded corners (14pt) and native sliders/pickers.

## Testing Decisions

- Test that updating settings reflects immediately in the controller (e.g. changing sampling intervals or thresholds).
- Test that switching categories displays the corresponding sub-panel without lag.
- Test that reset actions restore factory defaults.

## Out of Scope

- Remote cloud configuration syncing.
