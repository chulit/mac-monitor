# 04: Interactive usage timeline chart

**What to build:** Full-width interactive usage timeline card for normal monitoring state, featuring metric selector pill tabs (CPU, Memory, Disk, Network), custom Y-axis gridlines (0%-100%), X-axis timestamp labels, smooth bezier area curve, and interactive inspection tooltip with hairline marker.

**Blocked by:** 03 (metric cards).

**Status:** ready-for-agent

- [ ] Header shows active metric title (e.g. "CPU Usage") and segmented pill selector `[ CPU | Memory | Disk | Network ]`
- [ ] Switching tabs updates the curve, gradient area fill, and active theme color
- [ ] Y-axis displays percentages (100%, 75%, 50%, 25%, 0%) with subtle horizontal gridlines across the chart
- [ ] X-axis displays synchronized time markers (e.g. 09:20, 09:30, 09:40, 09:50, 10:00, 10:10)
- [ ] Interactive inspection tooltip showing timestamp (e.g. "10:00:14") and metric reading (e.g. "• CPU 68%") with a vertical guideline and data point circle

## Comments
