# CONTEXT.md — Ultimate Mac Monitor

Single-context glossary. Implementation-free: terms only, no modules, APIs, thresholds, or storage details.

## Glossary

### Monitoring

Ongoing local collection of system and process metrics. (PRD: monitoring, pemantauan)

### Sample

One timestamped observation. A sample carries its time and its data-quality status. Missing data is marked, never filled in.

### Unavailable

Status of a metric that cannot be accessed. Avoid: treating it as zero or as normal.

### Process

A running program instance with available identity and metadata. Avoid: treating PID as permanent identity — PIDs can be reused by other processes.

### Process tree

Parent-child grouping of processes. A subtree's aggregate behavior is stated separately from any single process's behavior.

### Anomaly (anomali)

A condition that deviates from a technical rule or from the local baseline.

### Technical rule (aturan teknis)

A fixed rule for critical conditions. A baseline never disables a technical rule.

### Baseline

The locally learned profile of normal behavior. Has a candidate baseline and an active baseline; status is one of Learning, Limited, Stable, or Stale. Learned only from samples judged normal; known anomalies and incidents are excluded.

### Duration and recurrence

How long a condition persists and how often it repeats. Used to separate momentary spikes from sustained conditions.

### Hysteresis and cooldown

Mechanisms that stop repeated flapping between states and repeated notifications for the same condition.

### Severity

Level assigned from duration, recurrence, and context. Avoid: equating severity with notification — notification is separately governed by cooldown and recovery.

### Incident (insiden)

The record of one detected occurrence: start, peak, and recovery times when determinable, linked metrics, event markers, relevant processes, evidence, and data limitations. Avoid: using "incident" for a timeline point (that is an event marker) or for a notification (that is an alert).

### Event marker

A point on the timeline marking a notable occurrence or a change in monitoring status. Avoid: calling it an incident.

### Alert

A notification about an incident, governed by severity, duration, recurrence, cooldown, deduplication, and recovery. Avoid: using "alert" for the incident record itself.

### Timeline

The single synchronized time axis of an investigation: related metrics, event markers, monitoring-status changes, and sampling gaps shown together.

### Evidence (bukti)

Traceable data supporting a conclusion. Every conclusion must be traceable to evidence (evidence-first).

### Process relevance (atribusi)

A ranked ordering of processes by measured contribution to the anomaly, each with its stated reason. Timing or parent-child relationships are never stated as cause-and-effect. Avoid: "cause"; use "relevant because…".

### Monitoring status

The state of observation itself: normal, high-detail, or reduced. Avoid: presenting monitoring status as system health.

### Reduced monitoring (observasi terbatas)

Lowered observation quality. Always shown with its reason and the affected metrics.

### High-detail investigation mode

A user-requested temporary increase in observation detail for one investigation session. It has a duration and resource limit, ends automatically, and its transitions are recorded on the timeline. Avoid: silent extension.

### Retention

Adaptive history policy: detailed data for a short period, summaries for long-term trends, special retention for critical or pinned incidents, growth bounded by a storage quota. Protected incidents are never deleted silently.

### Summary

A compact record of older data: time range, sample count, minimum, maximum, average, variation, threshold-exceeded duration, and notable events where available.

### Incident package (paket incident)

A versioned export artifact for one incident: manifest and identity, timeline and available samples, incident metadata and selected processes, summary, schema/rule/baseline versions, data-gap markers, and integrity information. Sensitive metadata is excludable before export.

### Archive (arsip)

An imported incident package, opened separately from local history. An archive never changes local monitoring history.

### Local AI explanation

Optional on-device interpretation of evidence. Its output separates measured facts, temporal correlation, causal hypotheses, uncertainty, and unavailable data. It never fabricates metrics, never guarantees causation without evidence, and never performs system actions. Core monitoring works without it.
