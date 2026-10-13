# 10: Wire full engine policies into the live app

**What to build:** the live app running the whole engine, not just rules: baseline learning, adaptive observation, retention, and notifications configured with the ticket 07 numbers.

**Blocked by:** 04 (App target with live dashboard), 07 (Fix numeric acceptance decisions).

**Status:** ready-for-agent

- [ ] The controller configures baselines (100/1000/3.0/1h), observation (2% budget, 3/3 hysteresis, 10 min cap), retention (7 days, 150M quota), and notifications (15 min cooldown) from the decided numbers
- [ ] Baseline status, observation mode, retention pressure, and notices are visible in the app
- [ ] No provisional numbers remain anywhere in app wiring
