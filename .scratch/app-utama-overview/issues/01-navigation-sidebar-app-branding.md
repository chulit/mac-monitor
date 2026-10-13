# 01: Navigation sidebar and app branding

**What to build:** Update `NavigationStore` and `RootView` sidebar navigation with complete macOS native styling: App icon badge with blue gradient, "Ultimate Mac Monitor" title, standard sidebar sections (Overview, Processes, Incidents with red badge "2", History, Settings), and selection state management.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] `AppSection` enum in `NavigationStore.swift` includes `overview`, `processes`, `incidents`, `history`, `settings`, with backward-compatible aliases for legacy callers (`.dashboard`, `.investigation`)
- [x] Sidebar renders an app header with rounded gradient icon and "Ultimate Mac Monitor" title
- [x] Sidebar navigation list includes Overview (`house.fill`), Processes (`list.bullet`), Incidents (with red badge "2"), History (`clock`), and Settings (`gearshape`)
- [x] Selected item displays with high-contrast active styling matching Apple HIG
- [x] Detail view cleanly routes to the corresponding section view based on selection

## Comments

## Notes (2026-10-13)

- `AppSection` pindah ke MonitoringEngine (`Sources/MonitoringEngine/AppSection.swift`) agar kontrak
  alias dan metadata section unit-tested; `NavigationStore` tinggal menyimpan pilihan.
- Alias `.dashboard` → `.overview` dan `.investigation` → `.incidents` sebagai static var
  deprecated; semua call site internal dimigrasi (PopoverView, RootView, NavigationStore).
- Badge Incidents BUKAN angka "2" statis dari mock: memakai live count `activeIncidentCount`
  dari EngineController, disembunyikan saat nol (sesuai user story spec: badge count of active
  incidents). `activeIncidents` juga dipakai ulang oleh PopoverView.
- Item Settings di sidebar membuka jendela settings issue 19 via `AppDelegate.openSettings()`;
  seleksi sidebar kembali ke section sebelumnya. Detail History masih placeholder sampai modul
  History mendarat; detail Incidents memakai TimelineView yang ada sampai modul Incidents mendarat.
- Belum terverifikasi di Mac: build Swift + tampilan sidebar/badge (tidak bisa build di VM Linux).
