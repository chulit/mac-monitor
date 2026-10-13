# 07: Investigation live findings and preliminary insights

**What to build:** Live Findings stream card and Preliminary Insights card displayed during active investigation session, including real-time findings with timestamps and severity icons, structured preliminary insight summaries, and the in-progress status info banner.

**Blocked by:** 06 (investigation progress card).

**Status:** ready-for-agent

- [x] "Live Findings" card with waveform header icon, displaying real-time stream of detected conditions with severity icons (red circle for high CPU, amber triangle for memory, blue wave for network, gray disk/circle) and relative timestamps ("just now", "15s ago", etc.)
- [x] "Preliminary Insights" card with lightbulb header icon, displaying synthesized summaries with colored badges (WindowServer high CPU, memory usage above average, background network activity)
- [x] Bottom info banner on Preliminary Insights card with `info.circle` stating: "Investigation is still in progress. Final report will be available shortly."
- [x] Split 2-column layout mirroring `b. overview - start-investigating.png`

## Comments

## Notes (2026-10-13)

- Engine (`OverviewCards.swift`): `liveFindings` (insiden terbaru dulu, hanya
  insiden engine — tidak ada temuan sintetis) dan `preliminaryInsights`
  (headline dari fakta "largest share" milik engine, detail dari hipotesis).
- Kedua kartu hanya tampil saat investigating, dalam baris 2 kolom di bawah
  kartu progres, ikut spring animation yang sama.
- Belum terverifikasi di Mac: `swift test` + tampilan kartu (tidak bisa build
  Swift di VM Linux).
