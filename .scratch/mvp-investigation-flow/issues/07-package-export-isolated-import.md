# 07: Package export plus isolated import

**What to build:** one incident exported as a versioned package that imports as a separate archive, leaving local history untouched per ADR-0001.

**Blocked by:** 06 (Retention summaries plus quota plus pinning).

**Status:** ready-for-agent

- [x] Export produces a versioned single-incident package with manifest, timeline, samples, metadata, summary, schema/rule/baseline versions, gap markers, and integrity information
- [x] Sensitive metadata can be excluded before export
- [x] Import validates format, integrity, duplicates, and version compatibility, and shows a preview before opening
- [x] The imported package opens as an isolated archive that never mutates local monitoring history
- [x] Migration runs on an internal copy, and re-analysis under newer algorithms is labeled as new, distinct from original results

## Comments

- Archive handling is its own module behind the package seam (`IncidentArchive`); domain types are `Codable`, with a custom encoding for incident provenance. Integrity is SHA-256 over canonical JSON (sorted keys, fixed date and float strategies).
- Redaction replaces process names with a placeholder in both identity and reason text, longest names first; structure, ids, and contributions survive, and the flag travels in the package.
- Validation order is format, then version, then integrity; preview is repeatable and duplicate-checked only on open. Re-analysis is engine work labeled and stored separately by the archive — the original is never rewritten.
- A frozen v0 schema is kept as the legacy reader; migration fills the newer fields with defaults, re-signs, and records its origin. Input bytes are never mutated (value semantics throughout).
