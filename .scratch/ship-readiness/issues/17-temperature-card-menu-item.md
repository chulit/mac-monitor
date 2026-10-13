# 17: Temperature card and menu-bar item live

**What to build:** the popover temperature card and the fifth menu-bar item showing live readings per the mockup.

**Blocked by:** 16 (Temperature sensor collectors).

**Status:** ready-for-agent

- [x] The temperature card shows the live value with sparkline and tint, replacing the unavailable state
- [x] The menu bar gains the temperature item in the mockup's position and format
- [x] Sensor gaps still render as honest unavailable, never stale or fabricated values

## Comments

- Duration conflict resolved by maintainer: the mockup's 30 minutes yields to the decided 600s session cap (Ship-07 stands). Button and captions stay at 10 minutes.
- Five live menu-bar items in mockup order (temperature with icon, CPU, memory, disk, network rate); readings older than five ticks render as unavailable, so a dead sensor can never masquerade as a frozen value.
- Verified by warning-free build plus the untouched engine suite (no UI seam, per agreement).
