# 21: Diagnose the menu-bar click termination

**What to build:** a proven root cause (not a theory) for the app dying when the status item is clicked, plus the fix.

**Blocked by:** none. Diagnosis in progress.

**Status:** ready-for-agent

- [x] Reproduce with field evidence (lifecycle log already narrows it to inside togglePopover)
- [x] Bisect content versus hosting: minimal popover content first
- [x] Fix verified by click test on the release build, not by reasoning alone

## Comments

- Evidence so far: `toggle` logged, no `toggle shown`, no quit line, no crash report, no Console trace. Duplicate-ID hardening (Ship-20 round) did not change the outcome, ruling that theory out.
- Closed: root cause proven with an lldb backtrace, not a theory. `chartDomain` in
  `Sources/MonitoringEngine/Presentation.swift` clamped every domain to `0...1`, so the
  network card (bytes/s) and the temperature card (°C) built a range like `1975...1`.
  Constructing that `ClosedRange` traps during the popover's first layout, which is why
  `hosting after` was logged and `toggle shown` never was. Reproduced with a throwaway
  self-trigger loop (exit 133 / SIGTRAP) and confirmed the same fatal error in a unit test
  at the public `chartDomain` seam before the fix.
- Fix: clamp applies to unit-scale readings only; other data pads around its own values.
  Regression test in `Tests/MonitoringEngineTests/ChartDomainTests.swift`.
- Bisect rounds 1-5 were superseded by the backtrace; content was never the cause.
- Verified by real click on the release build after the redesign: popover renders in full
  and the process keeps sampling.
