# 03: Metric stat cards with smooth gradient sparklines

**What to build:** Row of 4 metric cards (CPU, Memory, Disk, Network) with SF Symbol badges, large percentage/rate values, baseline deviation delta badges during investigation, and smooth cubic bezier sparklines with color-matched vertical gradient fills.

**Blocked by:** 02 (header and state foundation).

**Status:** ready-for-agent

- [ ] 4 cards rendered in an evenly spaced horizontal row with subtle borders, rounded corners (14pt), and elevation shadows
- [ ] Card 1 (CPU): chip icon, blue theme, percentage readout
- [ ] Card 2 (Memory): RAM icon, purple theme, percentage readout
- [ ] Card 3 (Disk): hard drive icon, green theme, percentage readout
- [ ] Card 4 (Network): Wi-Fi / network icon, sky blue theme, formatted throughput readout (e.g. "4 MB/s")
- [ ] Smooth cubic bezier sparklines with line stroke and vertical gradient area fills matching the card theme color
- [ ] When in investigation mode, displays red delta indicator badge (e.g. `↑ +24% from baseline`)

## Comments
