# 06: Retention summaries plus quota plus pinning

**What to build:** history that compacts with age under a storage quota while protecting pinned and critical incidents from silent deletion.

**Blocked by:** 03 (Baseline learning plus contextual deviation).

**Status:** ready-for-agent

- [x] Older detail compacts to summaries preserving time range, sample count, min/max/average, variation, threshold-exceeded duration, and notable events where available
- [x] The storage quota bounds history growth; near-quota pressure summarizes old detail while preserving metadata
- [x] Pinned and critical incidents receive protected retention and are never deleted silently

## Comments

- History lives behind the sampling seam: the pipeline records every evaluated batch and compacts under an injected retention policy. Quota counts full-detail samples only; summaries and incident records are metadata.
- Protected spans are temporal and cover all metrics in range (incident evidence is cross-metric); rule-source incidents are critical by construction, pinned incidents join the same protection. Recovery points fall outside the span and compact normally.
- Summaries split at protected-span boundaries so no summary range implies coverage of protected detail. Gap-only ranges summarize with zeroed statistics.
- Nothing is ever deleted in this ticket — incident records accumulate and protected evidence survives, so "never deleted silently" holds by construction. Record aging/deletion policy is future work.
