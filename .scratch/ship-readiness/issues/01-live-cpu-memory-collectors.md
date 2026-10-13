# 01: Live CPU and memory collectors behind the sampling seam

**What to build:** real system samples flowing through the same sampling seam the synthetic adapter uses, so the dashboard shows live Mac data with engine behavior unchanged.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] Host collector adapters produce timestamped samples with availability status for CPU and memory
- [x] Existing engine behavior is unchanged and the synthetic suite stays green
- [x] Collection overhead is observable (intervals and cost visible, not hidden)

## Comments

- `HostCollector` is an adapter at the agreed sampling seam (no new seam): Mach `host_statistics` for CPU deltas and `vm_statistics64` for memory, shaped into timestamped samples. CPU needs two reads for a delta, so the first collection honestly reports unavailable.
- Memory share is a documented approximation (attributed pages over physical pages, clamped to a fraction); syscall failures surface as unavailable, never fabricated.
- Cost visibility: each collection measures its own duration through the injected clock (`lastDuration`); sampling intervals remain recorded by the engine's observed intervals. Syscall-failure paths are untestable deterministically and covered by code review only.
