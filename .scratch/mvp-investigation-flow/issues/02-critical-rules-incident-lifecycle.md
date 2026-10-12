# 02: Critical rules plus incident lifecycle

**What to build:** sustained critical conditions become incidents with a full lifecycle, while momentary spikes stay quiet and repeat notifications are suppressed.

**Blocked by:** 01 (Pipeline skeleton plus sampling seam plus synthetic harness).

**Status:** ready-for-agent

- [x] A sustained critical condition creates and updates an incident with start, peak, and recovery times when determinable
- [x] A momentary spike does not create an incident
- [x] Cooldown and deduplication suppress repeat notifications for the same ongoing condition
- [x] Recovery is detected and reported
- [x] Critical conditions are detected even while the baseline is still learning

## Comments

- Rules are injected configuration (`TechnicalRule`: threshold, trigger/recovery durations, cooldown); no numeric thresholds are hardcoded. Chosen semantic, locked by test: an excursion beginning inside cooldown opens nothing even if it outlives the cooldown end.
- Baseline-maturity independence holds by construction: no baseline exists yet and the rule path consults none. No test written for it — asserting it now would be tautological.
- `recoveredAt` is the first normal sample of the qualifying recovery run (when the condition ended), not when recovery was confirmed.
