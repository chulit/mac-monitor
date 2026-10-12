# 09: Safe process control

**What to build:** process termination with confirmations proportional to risk, where reused identities can never cause action against the wrong program.

**Blocked by:** 08 (Dashboard plus process tree plus timeline surfaces).

**Status:** ready-for-agent

- [x] Ordinary termination requires user confirmation
- [x] Force quit requires a second confirmation with identity re-verification, so a reused process identity never targets the wrong program
- [x] Permission and system-protection failures are explained accurately
- [x] Nothing terminates processes automatically, including from AI output

## Comments

- Control runs behind the confirmed action seam: `ProcessControl` accepts an executor adapter (host terminator in production, recording fake in tests). No test ever executes a real action.
- Identity is re-verified on every action, not just force quit: a vacant pid reports already-exited, a mismatched token refuses as identity-changed, so PID reuse can never strike the wrong program.
- Nothing is automatic by construction: every action method takes explicit confirmations, zero-confirmation calls never reach the executor, and no API accepts AI output.
- The identity token is opaque here (host collectors will source it from start time or exec identity); bridging engine `Process` ids to control identities is host-wiring work.
