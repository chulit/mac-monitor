# 06: Overhead benchmark harness

**What to build:** measured CPU, memory, energy, and disk activity on all three monitoring levels against budgets.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam).

**Status:** ready-for-agent

- [ ] Idle, normal, and investigation levels are each measured for CPU, memory, energy, and disk writes
- [ ] Adaptive degradation is observed engaging when budgets are exceeded
- [ ] Results read against the budgets fixed in ticket 07, not inferred after the fact
