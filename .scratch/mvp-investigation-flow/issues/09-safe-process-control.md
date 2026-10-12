# 09: Safe process control

**What to build:** process termination with confirmations proportional to risk, where reused identities can never cause action against the wrong program.

**Blocked by:** 08 (Dashboard plus process tree plus timeline surfaces).

**Status:** ready-for-agent

- [ ] Ordinary termination requires user confirmation
- [ ] Force quit requires a second confirmation with identity re-verification, so a reused process identity never targets the wrong program
- [ ] Permission and system-protection failures are explained accurately
- [ ] Nothing terminates processes automatically, including from AI output
