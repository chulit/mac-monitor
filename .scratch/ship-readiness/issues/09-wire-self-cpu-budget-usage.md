# 09: Wire self CPU usage into budget evaluation

**What to build:** the app controller reporting the monitor's own CPU fraction as resource usage every evaluation, so the 2% budget from ticket 07 actually engages.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [ ] Each tick looks up the monitor's own pid share from process samples and passes it as usage
- [ ] Usage stays a fraction (0–1) matching the budget definition; missing self-readings pass nil, never zero
- [ ] Over-budget operation is observed degrading the live app, under-budget recovering it
