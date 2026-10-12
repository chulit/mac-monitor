# 07: Package export plus isolated import

**What to build:** one incident exported as a versioned package that imports as a separate archive, leaving local history untouched per ADR-0001.

**Blocked by:** 06 (Retention summaries plus quota plus pinning).

**Status:** ready-for-agent

- [ ] Export produces a versioned single-incident package with manifest, timeline, samples, metadata, summary, schema/rule/baseline versions, gap markers, and integrity information
- [ ] Sensitive metadata can be excluded before export
- [ ] Import validates format, integrity, duplicates, and version compatibility, and shows a preview before opening
- [ ] The imported package opens as an isolated archive that never mutates local monitoring history
- [ ] Migration runs on an internal copy, and re-analysis under newer algorithms is labeled as new, distinct from original results
