# 21: Diagnose the menu-bar click termination

**What to build:** a proven root cause (not a theory) for the app dying when the status item is clicked, plus the fix.

**Blocked by:** none. Diagnosis in progress.

**Status:** ready-for-agent

- [ ] Reproduce with field evidence (lifecycle log already narrows it to inside togglePopover)
- [ ] Bisect content versus hosting: minimal popover content first
- [ ] Fix verified by click test on the release build, not by reasoning alone

## Comments

- Evidence so far: `toggle` logged, no `toggle shown`, no quit line, no crash report, no Console trace. Duplicate-ID hardening (Ship-20 round) did not change the outcome, ruling that theory out.
