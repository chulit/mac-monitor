# 09: Wire self CPU usage into budget evaluation

**What to build:** the app controller reporting the monitor's own CPU fraction as resource usage every evaluation, so the 2% budget from ticket 07 actually engages.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [x] Each tick looks up the monitor's own pid share from process samples and passes it as usage
- [x] Usage stays a fraction (0–1) matching the budget definition; missing self-readings pass nil, never zero
- [x] Over-budget operation is observed degrading the live app, under-budget recovering it

## Comments

- The lookup is a pure, tested function (`totalShare`): sums own samples, clamps to a fraction, nil when absent. The controller wiring is three thin lines with no logic of its own (verified by warning-free build, per the no-UI-seam agreement).
- Degrade/recover behavior itself is ticket 05's tested engine behavior; what this ticket adds is the live usage feed. Observing it engage in the running app is manual: run the app, watch the monitoring status shift under load.
