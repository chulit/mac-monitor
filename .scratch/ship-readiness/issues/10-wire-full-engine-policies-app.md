# 10: Wire full engine policies into the live app

**What to build:** the live app running the whole engine, not just rules: baseline learning, adaptive observation, retention, and notifications configured with the ticket 07 numbers.

**Blocked by:** 04 (App target with live dashboard), 07 (Fix numeric acceptance decisions).

**Status:** ready-for-agent

- [x] The controller configures baselines (100/1000/3.0/1h), observation (2% budget, 3/3 hysteresis, 10 min cap), retention (7 days, 150M quota), and notifications (15 min cooldown) from the decided numbers
- [x] Baseline status, observation mode, retention pressure, and notices visible in the app
- [x] No provisional numbers remain anywhere in app wiring

## Comments

- Wiring only: every value comes from Ship-07 (including the three derived numbers decided with the maintainer: severity 300s, intervals 1/5/0.5s, baseline timing same-as-detection). The 60s warning window is 10% of the session cap, recorded as a UX detail.
- Dashboard shows baseline statuses, storage pressure, and the latest notices; observation mode was already visible. Notices cap at the 50 latest.
- Verified by warning-free build plus the untouched engine suite (no UI seam, per agreement); all policy behavior itself is covered by existing engine tests.
