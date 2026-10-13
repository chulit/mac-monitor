# 07: Investigation live findings and preliminary insights

**What to build:** Live Findings stream card and Preliminary Insights card displayed during active investigation session, including real-time findings with timestamps and severity icons, structured preliminary insight summaries, and the in-progress status info banner.

**Blocked by:** 06 (investigation progress card).

**Status:** ready-for-agent

- [ ] "Live Findings" card with waveform header icon, displaying real-time stream of detected conditions with severity icons (red circle for high CPU, amber triangle for memory, blue wave for network, gray disk/circle) and relative timestamps ("just now", "15s ago", etc.)
- [ ] "Preliminary Insights" card with lightbulb header icon, displaying synthesized summaries with colored badges (WindowServer high CPU, memory usage above average, background network activity)
- [ ] Bottom info banner on Preliminary Insights card with `info.circle` stating: "Investigation is still in progress. Final report will be available shortly."
- [ ] Split 2-column layout mirroring `b. overview - start-investigating.png`

## Comments
