# 08: Privileged helper necessity verdict

**What to build:** an evidence-backed verdict on whether a privileged helper is needed for any metric, with a least-privilege design if yes.

**Blocked by:** 01 (Live CPU and memory collectors behind the sampling seam), 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [x] Each metric documents whether unprivileged collection suffices, with evidence
- [x] If a helper is needed: narrow operations only, least privilege, transparent install and removal
- [x] If not needed: the verdict records why, and no helper ships

## Comments

- The verdict is evidence-driven, never assumed: a pure assessment maps probe outputs (system samples, process samples, task-port availability) to per-metric findings, and `helperNeeded` stays false without positive evidence of a privileged-only need — including an explicit re-run note when the probe itself comes back incomplete.
- Live probes confirm the boundary both ways: all MVP metrics collect unprivileged on this machine, while cross-process task ports are denied (a live `task_for_pid` check) — which is exactly where a future helper would live if per-process task-port metrics ever arrive. No helper ships.
- Least-privilege design and install/removal transparency apply only if that verdict ever flips; there is nothing to install today.
