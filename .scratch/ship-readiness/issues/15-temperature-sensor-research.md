# 15: Temperature and per-component sensor research

**What to build:** a research verdict on reading temperature sensors (CPU average/performance/efficiency, GPU, SSD) across supported Mac models, unprivileged if possible.

**Blocked by:** none. Research first; collectors follow only on a positive verdict.

**Status:** ready-for-agent

- [x] Candidate APIs (SMC keys per model, IOKit alternatives) documented with availability and privilege requirements
- [x] A spike collector proves readings on the test matrix or records exactly where it fails
- [x] On success: metric ids and units fixed for the popover temperature card and detail section; on failure: the unavailable state stays with reasons

## Verdict (probed 2026-10-13 on MacBook Air M2, Mac14,2, unprivileged)

Readable without privileges via the AppleSMC user client: **Tp01** (~54°C, CPU), **Tp05** (~53°C, second CPU-zone sensor, exact role undocumented), **Ts0S** (~46°C, storage). 1762 keys total; the rest of the `flt` keys are voltages/currents, not temperatures.

Not found on this model: **TG0P/TG0D** (GPU), per-cluster CPU split, TC/TM/TH keys. No GPU or efficiency-cluster temperature is obtainable here — those mockup rows stay honestly unavailable.

Fixed metric ids for ticket 16: `temperature` (primary, Tp01); detail rows CPU (Average)←Tp01, CPU (Secondary)←Tp05 marked provisional, SSD←Ts0S; GPU/Performance/Efficiency report unavailable.

Implementer notes (learned the hard way): the user-client struct is 80 bytes — Swift packs the 9-byte keyInfo member without C's trailing pad, so pad explicitly and assert the size; Apple Silicon reads require the input keyInfo pre-filled from a keyinfo call or every read fails; `flt` values are little-endian; keyinfo-then-read doubles call count, budget accordingly.
