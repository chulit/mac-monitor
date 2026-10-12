# ADR-0001: Imported incident packages open as separate archives

Status: accepted

## Context

An incident package carries another machine's timeline, samples, and analysis results. Two designs were possible: merge the imported data into local monitoring history, or open it as an isolated archive.

Merging would corrupt baseline learning (foreign samples judged by another machine's baseline), break evidence traceability (which samples are truly local?), and risk silently altering or deleting local history under quota pressure.

## Decision

An imported package opens as a separate archive. It never mutates local monitoring history. Schema migration runs on an internal copy, never on the original artifact. Any re-analysis with newer algorithms is labeled as new analysis, distinct from the package's original results.

## Consequences

- Baseline learning and retention accounting only ever see local samples.
- Archive viewing needs no quarantine beyond the existing package validation (format, integrity, version compatibility, duplicate detection) since archives are inert data.
- Comparing an archive against local history is an explicit, labeled operation, never an implicit merge.
