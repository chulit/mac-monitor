# 01: Live CPU and memory collectors behind the sampling seam

**What to build:** real system samples flowing through the same sampling seam the synthetic adapter uses, so the dashboard shows live Mac data with engine behavior unchanged.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Host collector adapters produce timestamped samples with availability status for CPU and memory
- [ ] Existing engine behavior is unchanged and the synthetic suite stays green
- [ ] Collection overhead is observable (intervals and cost visible, not hidden)
