# Spec: MVP Investigation Flow

Status: ready-for-agent

## Problem Statement

Mac users notice slowdowns, high resource usage, or strange behavior but cannot tell what happened, when it started, which processes were involved, or whether the data they see is complete. Existing tools show live numbers without history, flag spikes without context, and never explain what the evidence actually supports — leaving users to guess at causes and actions.

## Solution

A local-first monitoring application that continuously observes the system, detects anomalies through technical rules and a locally learned baseline, records each occurrence as an incident with a synchronized timeline of metrics and event markers, ranks relevant processes with stated evidence-based reasons, retains useful history under a storage quota, and exports or imports single incidents as versioned packages — all without uploading monitoring data anywhere.

## User Stories

### Seeing system and process state

1. As a general user, I want to see current system conditions at a glance, so that I know whether my Mac is behaving normally.
2. As a general user, I want unavailable metrics to be labeled as unavailable rather than shown as zero, so that I am never misled by missing data.
3. As a developer, I want to browse processes with parent-child grouping that I can expand and collapse, so that I can understand which program group is consuming resources.
4. As a developer, I want subtree aggregates stated separately from individual process metrics, so that I do not confuse a group's total with one member's usage.
5. As a productivity user, I want to search and filter the process list, so that I can find the program I suspect quickly.
6. As a power user, I want every sample shown with its timestamp, so that I can correlate what I saw with what I was doing.

### Detection and baselines

7. As a productivity user experiencing a slowdown, I want critical conditions to be detected even while the baseline is still learning, so that I am protected from day one.
8. As a general user, I want brief momentary spikes to be treated differently from sustained pressure, so that I am not alarmed by harmless blips.
9. As a power user, I want the baseline's status (Learning, Limited, Stable, Stale) to be visible, so that I know how much to trust contextual deviation findings.
10. As a power user, I want baseline changes to record when, why, and on how much qualifying data they happened, so that I can judge whether the baseline is mature.
11. As a productivity user, I want repeated notifications for the same ongoing condition to be suppressed, so that I am informed once and not nagged.
12. As a general user, I want to be told when a condition has recovered, so that I know the incident is over.
13. As a general user, I want monitoring status (normal, high-detail, reduced) shown separately from system health, so that I never mistake "we are observing less" for "the Mac is fine".

### Investigating an incident

14. As a productivity user who got an alert, I want to open the incident and see start, peak, and recovery times when determinable, so that I know the shape of what happened.
15. As a developer, I want all related metrics on one synchronized timeline with event markers, so that I can see what changed together.
16. As a developer, I want sampling gaps and access limitations shown on the timeline, so that I know where the evidence is thin.
17. As a power user, I want the ranked processes to each state the reason for relevance, so that I can verify the claim against the evidence.
18. As a general user, I want time-adjacent or parent-child processes to never be presented as proven causes, so that I am not led into false certainty.
19. As a developer, I want the timeline to note which rule and baseline versions produced the finding, so that later re-analysis is comparable.
20. As a productivity user deep in an investigation, I want to request higher-detail observation with a visible time limit, so that I can gather better evidence for this session.
21. As a general user, I want high-detail observation to end automatically with a warning beforehand, so that extra overhead never runs silently.
22. As a power user, I want every observation-quality transition recorded on the timeline, so that evidence remains interpretable after the fact.

### Controlling processes safely

23. As a general user, I want terminating a process to require my confirmation, so that I never kill something by accident.
24. As a productivity user, I want a second confirmation with identity re-verification before a force quit, so that a reused process identity never causes action against the wrong program.
25. As a general user, I want permission or system-protection failures explained accurately, so that I understand why an action was refused.

### History, retention, and packages

26. As a power user, I want older history available as summaries (range, sample count, min/max/average, variation, threshold durations, notable events), so that long-term trends survive without unbounded growth.
27. As a power user, I want to pin incidents I care about, so that quota pressure summarizes old detail but never silently deletes what I protected.
28. As a developer, I want to export one incident as a versioned package including its timeline, samples, metadata, summaries, and the rule/baseline versions behind it, so that I can share or archive the full evidence.
29. As a privacy-conscious user, I want to exclude sensitive metadata before export, so that sharing never leaks more than I intend.
30. As a developer receiving a package, I want to preview its contents with format, integrity, duplicate, and compatibility checks before import, so that I know exactly what I am opening.
31. As a power user, I want an imported package to open as a separate archive that leaves local history untouched, so that foreign data never contaminates my baseline or timeline.

### Assistance and privacy

32. As a general user on a compatible device, I want an on-device explanation that separates measured facts, time correlation, causal hypotheses, uncertainty, and missing data, so that I get help without false certainty.
33. As a general user on a device without on-device AI, I want full core monitoring with no cloud fallback, so that my data still never leaves my Mac.
34. As a privacy-conscious user, I want a guarantee that no monitoring data or usage telemetry is uploaded, with updates being the only network activity, so that I can trust the application with system visibility.
35. As a general user, I want the normal dashboard to stay simple with advanced detail appearing only when needed, so that the application feels approachable until I need depth.
36. As a power user, I want reduced monitoring to always show its reason and affected metrics in context, so that I can discount exactly the graphs and findings it touches.

## Implementation Decisions

- The monitoring pipeline (collection scheduling, detection, baselines, retention, attribution) is one deep module behind a single sampling seam: it accepts a stream of timestamped samples carrying availability status, plus an injected clock, and returns incidents, evidence, and retention effects. Tests and host collectors cross the same seam.
- Depth rationale: hysteresis, cooldown, baseline maturation, degradation policy, and high-detail session limits all live behind that one interface, giving one synthetic-stream adapter leverage across the whole synthetic anomaly suite and keeping verification local to the module.
- Two adapters exist across the sampling seam, making it real: host collector adapters in production and a deterministic synthetic-stream adapter in tests. The clock is a parameter of the interface: a real clock adapter in production, a controlled clock in tests, so duration, hysteresis, cooldown, retention windows, and session limits are reproducible.
- Detection evaluates samples to incident and evidence results rather than mutating shared state; the module accepts its collectors, clock, and storage and never constructs them.
- The baseline keeps a candidate and an active generation with visible status and a recorded change history (time, reason, algorithm version, qualifying sample count); only impacted metrics recalibrate after major system change, and an immature baseline never suppresses technical rules.
- Incident archive handling is a second deep module behind the package seam: export one incident to a versioned package, validate/preview/import one as an isolated archive. Per ADR-0001, import never mutates local history, migration runs on an internal copy, and re-analysis under newer algorithms is labeled as new.
- The package interface's invariants (callers must know): archives are inert data and never execute; sensitive metadata exclusion happens before export; gap markers and actual sampling intervals travel inside the package.
- Process relevance ranking always pairs each entry with its evidence-based reason; timing and parent-child proximity are correlation signals, never stated as causation. Identity re-verification precedes any termination step.
- Observation-quality transitions (degradation, recovery, high-detail start/warning/end) are first-class timeline entries with reasons and affected metrics, so graphs, detection, and investigation stay interpretable under reduced monitoring.
- Advanced areas (rich notifications, proven hardware sensors, menu-bar and widget surfaces, on-device explanation, historic comparison) are sequenced after the core detect-to-archive journey and must not delay it; they read the same shared observation snapshot — a data shape, not a module — rather than adding independent polling.
- The on-device explanation layer stays minimal: evidence in, explanation out, no surrounding framework. Its seam is hypothetical until a second adapter appears, so it deepens only when one does.

## Testing Decisions

- A good test crosses only the two agreed seams and asserts external behavior: given a synthetic sample stream and controlled clock, it asserts incidents emitted, severity, timeline contents, relevance reasons, retention effects, and package round-trip outcomes. No test reaches past either interface into internals.
- The pipeline module is tested through the sampling seam: reproducible scenarios for normal operation, brief spikes, sustained pressure, missing data, and baseline shifts, asserting rule-vs-baseline interplay, duration/recurrence handling, hysteresis, cooldown, deduplication, and recovery.
- Archive handling is tested through the package seam: export/import round-trips, integrity and compatibility validation, duplicate detection, preview contents, sensitive-metadata exclusion, and proof that import leaves local history unchanged.
- Prior art: greenfield repo with no existing tests; the PRD's synthetic anomaly suite and release-gate scenarios are the prior art shaping the scenario list. UI coverage stays thin, asserting the same engine outputs rather than opening a third seam.
- Numeric acceptance thresholds (overhead budgets, detection quality rates, retention periods) are set before the release candidate, not inferred from results, per the PRD's release-gate principle.

## Out of Scope

- Automatic system actions or process termination driven by AI output.
- Any upload of monitoring data or usage telemetry; any cloud AI fallback for devices without on-device capability.
- Guarantees that every hardware metric exists on every Mac model — inaccessible metrics are reported unavailable.
- Guaranteed root-cause identification; explanation outputs always carry uncertainty and missing-data statements.
- Privileged helper operations beyond narrowly defined, least-privilege needs with transparent install/remove (only if proven necessary).
- Feature parity for advanced surfaces (menu bar richness, widgets, hardware sensors, historic comparison) with the core investigation journey; they follow, not lead.

## Further Notes

- Vocabulary throughout follows `CONTEXT.md` (incident vs event marker vs alert; relevance vs causation; monitoring status vs system health); any conflict with an ADR is flagged rather than silently overridden — this spec conforms to ADR-0001.
- The two agreed seams stand: the sampling interface with injected clock for the engine, and the package interface for archive handling. No UI-level seam is proposed.
- Numeric budgets, retention periods, detection thresholds, package format details, and device/AI compatibility lists remain open product decisions to be fixed before the release candidate.
