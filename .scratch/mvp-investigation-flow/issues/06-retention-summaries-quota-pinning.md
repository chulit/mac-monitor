# 06: Retention summaries plus quota plus pinning

**What to build:** history that compacts with age under a storage quota while protecting pinned and critical incidents from silent deletion.

**Blocked by:** 03 (Baseline learning plus contextual deviation).

**Status:** ready-for-agent

- [ ] Older detail compacts to summaries preserving time range, sample count, min/max/average, variation, threshold-exceeded duration, and notable events where available
- [ ] The storage quota bounds history growth; near-quota pressure summarizes old detail while preserving metadata
- [ ] Pinned and critical incidents receive protected retention and are never deleted silently
