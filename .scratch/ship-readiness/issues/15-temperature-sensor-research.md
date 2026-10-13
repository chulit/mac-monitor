# 15: Temperature and per-component sensor research

**What to build:** a research verdict on reading temperature sensors (CPU average/performance/efficiency, GPU, SSD) across supported Mac models, unprivileged if possible.

**Blocked by:** none. Research first; collectors follow only on a positive verdict.

**Status:** ready-for-agent

- [ ] Candidate APIs (SMC keys per model, IOKit alternatives) documented with availability and privilege requirements
- [ ] A spike collector proves readings on the test matrix or records exactly where it fails
- [ ] On success: metric ids and units fixed for the popover temperature card and detail section; on failure: the unavailable state stays with reasons
