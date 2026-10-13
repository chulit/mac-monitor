# 20: Honest system CPU plus popover wash fix

**What to build:** system CPU derived from per-process time deltas instead of frozen Mach ticks, and sparkline rendering that cannot bleed outside its frame.

**Blocked by:** 02 (Process enumeration with stable identity tokens).

**Status:** ready-for-agent

- [x] System CPU shares come from summed rusage deltas over elapsed wall time, verified against live host counters
- [x] Popover and dashboard sparklines render through a clipped custom path, with no Charts overflow possible
- [x] No surface can display a permanently pinned 100% again without a matching incident

## Comments

- Root cause proven by probe: Mach idle ticks advanced 0 over 2 real seconds on Apple Silicon (tickless kernel), so the old fraction read a permanent ~1.0. System CPU now derives from summed per-process rusage times over wall elapsed; `HostCollector` drops the broken Mach path and keeps memory/disk.
- Custom `Sparkline` (explicit paths, clipped frame) replaces Charts in dense cards; the big incident chart keeps Charts where it renders correctly.
- The verdict test caught the migration honestly: it now assembles assessed samples the way the live app does (host plus derived system CPU).
