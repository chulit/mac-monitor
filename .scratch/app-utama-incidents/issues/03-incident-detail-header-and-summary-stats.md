# 03: Incident detail header and summary stats

**What to build:** The header section and summary statistics cards of the selected incident in the right panel.

**Blocked by:** 01, 02.

**Status:** ready-for-agent

- [x] Header with large incident icon badge, title (e.g. "High CPU Usage"), active status badge (`Active`), action menu (`···`), primary responsible process ("WindowServer"), and incident timing ("Apr 28, 2025 at 10:13 • Ongoing for 2 minutes")
- [x] Summary stats row displaying:
  - Peak CPU (e.g. 92%)
  - Average CPU (e.g. 68%)
  - Duration (e.g. "Ongoing" or exact time)
  - Affected Processes count (e.g. 3)

## Comments

## Notes (2026-10-14)

- Label stat mengikuti metrik primer insiden (mis. "Peak Memory").
- Nilai "—" bila timeline/sampel tidak tersedia — tidak ada angka nol
  yang difabrikasi.
- Belum terverifikasi di Mac: `swift test` + tampilan (tidak bisa build
  Swift di VM Linux).
