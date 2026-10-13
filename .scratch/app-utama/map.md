# Map: App Utama (Main App) UI Design Implementation

Feature design reference: `docs/plans/design/2. app-utama/`

## Group Overview

Seluruh perancangan UI App Utama dipecah dan dikelompokkan ke dalam 5 modul fungsional sesuai struktur desain asli:

1. **Overview Module**: `.scratch/app-utama-overview/`
   - Spec: [spec.md](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-overview/spec.md)
   - Issues: 8 tiket ([01](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-overview/issues/01-navigation-sidebar-app-branding.md) s/d [08](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-overview/issues/08-engine-integration-verification-polish.md))
   - Cakupan: Landing overview, 4 kartu metrik (CPU, Memory, Disk, Network) + sparkline gradien, timeline chart interaktif + tooltip, recent incidents, top processes, dan high-detail investigation mode (donut gauge, 3 fase, live findings, preliminary insights).

2. **Processes Module**: `.scratch/app-utama-processes/`
   - Spec: [spec.md](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-processes/spec.md)
   - Issues: 6 tiket ([01](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-processes/issues/01-processes-header-search-and-summary-cards.md) s/d [06](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-processes/issues/06-process-detail-actions-and-related-processes.md))
   - Cakupan: Tabel proses & hierarki parent-child ("Show Process Tree"), pencarian, filter, kartu ringkasan, dan Process Detail view lengkap (dual timeline charts, metadata proses, resource usage details, kontrol terminasi aman, related processes).

3. **Incidents Module**: `.scratch/app-utama-incidents/`
   - Spec: [spec.md](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-incidents/spec.md)
   - Issues: 6 tiket ([01](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-incidents/issues/01-incidents-split-layout-and-filter-tabs.md) s/d [06](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-incidents/issues/06-incident-detail-event-trail-timeline.md))
   - Cakupan: Split-view incident center, filter All/Active/Resolved, rentang waktu, kartu insiden dengan badge status, detail insiden dengan summary stats, grafik metrik dengan arsiran periode insiden, tabel atribusi proses terkait dengan bar merah, dan jejak kronologis event trail.

4. **History Module**: `.scratch/app-utama-history/`
   - Spec: [spec.md](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-history/spec.md)
   - Issues: 5 tiket ([01](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-history/issues/01-history-header-and-system-activity-chart.md) s/d [05](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-history/issues/05-history-detail-affected-processes-and-system-context.md))
   - Cakupan: Trend aktivitas sistem multi-hari, filter metrik tab, tabel riwayat insiden dengan filter severity (All/High/Medium/Low), dan History Detail view (ringkasan insiden, timeline grafik dengan periode kejadian, detail proses utama, konteks sistem memori/disk/network, aksi share incident).

5. **Settings Module**: `.scratch/app-utama-settings/`
   - Spec: [spec.md](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-settings/spec.md)
   - Issues: 7 tiket ([01](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-settings/issues/01-settings-layout-and-category-navigation.md) s/d [07](file:///Users/kholid/Documents/Project/Swift/ultimate-mac-monitor/.scratch/app-utama-settings/issues/07-settings-privacy-security-and-about-panels.md))
   - Cakupan: Layout dua kolom dengan 7 kategori sub-panel: General, Monitoring, Alert & Notifications, Data & Storage, Appearance, Privacy & Security, dan About.

## Decisions So Far
- Semua modul mempertahankan pedoman native Apple Design (`/apple-design`), semantic typography SF Pro, dynamic system colors (Light & Dark mode), dan fluid micro-animations.
- Seam arsitektur berakar pada `EngineController` dan `MonitoringEngine`, menyajikan data riil dan transisi status secara konsisten.
