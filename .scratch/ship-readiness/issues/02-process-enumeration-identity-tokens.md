# 02: Process enumeration with stable identity tokens

**What to build:** a live process list with parent links and reuse-safe identity tokens, bridging engine process ids to control identities.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] Enumeration yields process identity, metadata, and parent links for the process tree
- [x] Identity tokens survive PID reuse (sourced from start time or exec identity, never the PID alone)
- [x] Control identities bridge to the tokens the action seam verifies

## Comments

- `ProcessCollector` is an adapter at the sampling seam over libproc (`proc_listallpids`, `proc_pidinfo`, `proc_pid_rusage`): per-process CPU shares from rusage deltas over caller-provided time, normalized by processor count. Newly seen processes are omitted until their second sighting, never zero-filled.
- Tokens bind pid to process start time (`pid-sec-usec`); the collector retains the current identity map behind `identity(for:)`, and the bridge test wires a live token through the action seam's fake into a recorded (never executed) termination.
- Previous maps are replaced wholesale each collection, so exited pids drop by construction. `pid_t` stays `Int32` inside the collector with explicit conversion at the `Int`-based control boundary.
- Exit races and vanished processes skip silently via syscall-failure guards (review-only coverage); the pid-list buffer grows and retries boundedly.
