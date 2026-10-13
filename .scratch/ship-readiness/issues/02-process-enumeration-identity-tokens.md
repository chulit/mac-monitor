# 02: Process enumeration with stable identity tokens

**What to build:** a live process list with parent links and reuse-safe identity tokens, bridging engine process ids to control identities.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Enumeration yields process identity, metadata, and parent links for the process tree
- [ ] Identity tokens survive PID reuse (sourced from start time or exec identity, never the PID alone)
- [ ] Control identities bridge to the tokens the action seam verifies
