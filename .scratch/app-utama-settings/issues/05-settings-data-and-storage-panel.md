# 05: Settings Data & Storage sub-panel

**What to build:** The Data & Storage settings sub-panel (`D. Settings - Data & Storage.png`) including Retention policy, Storage breakdown, Data options, and Disk management.

**Blocked by:** 01.

**Status:** ready-for-agent

- [x] "Data Retention" card with options: 7 Days, 30 Days (selected), 90 Days, and Custom, with info notice
- [x] "Storage Usage" breakdown bar card showing real counts (metric samples, incidents, cached chart points) and the debug-log file size
  - Deviasi dari mock: bukan "512 MB / 5 GB" fiktif — angka MB per kategori tidak ada datanya, jadi yang ditampilkan adalah hitungan asli (samples/incidents/points) + ukuran file log. Segmen "Other" tidak ada karena tidak ada kategori lain yang terukur.
- [x] "Data Options" card with switches: Store System Metrics, Store Incidents, Store Logs, Enable Cache
- [x] "Disk Management" card with actions: "Clear History", "Clear Cache", and "📁 Open Data Folder"

## Comments
