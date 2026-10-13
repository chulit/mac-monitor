# 03: Settings Monitoring sub-panel

**What to build:** The Monitoring settings sub-panel (`B. Settings - Monitoring.png`) including Sampling Intervals, Monitored Metrics toggles, and Resource Caps.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] "Monitoring Mode" selector cards with descriptions (Normal, Reduced, High Detail)
- [x] "Sampling Intervals" card with preset buttons (Balanced/High Detail/Low Overhead) and individual metric interval sliders:
  - Deviasi dari mock: bukan "Custom dropdown" — preset buttons + slider per metrik sudah mencakup fungsi custom.
  - CPU (1 second)
  - Memory (2 seconds)
  - Disk (5 seconds)
  - Network (2 seconds)
  - Temperature (2 seconds)
- [x] "Monitored Metrics" card with individual switches: CPU Usage, Memory, Disk, Network, Temperature
- [x] "Resource Limits" sliders at bottom

## Comments
