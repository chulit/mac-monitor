# 19: Minimal settings window behind the gear

**What to build:** a settings window where every control is wired: launch at login, sampling interval, and restore of the Ship-07 defaults.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] The gear opens a settings window (no dead controls anywhere)
- [x] Launch-at-login toggles the real login item state
- [x] The sampling interval selector restarts collection at the chosen cadence
- [x] Restore returns every value to the decided Ship-07 numbers
- [x] The custom logo swaps in here when the asset arrives (placeholder until then)

## Notes (2026-10-13)

- Gear di popover kini memanggil `AppDelegate.openSettings()` yang membuka NSWindow berisi
  `SettingsView`; tombol tidak lagi membuka jendela utama seperti sebelumnya.
- `SettingsStore` (MonitoringEngine, unit-tested) menyimpan `MonitorSettings` ke UserDefaults,
  menulis launch-at-login lewat protokol `LoginItemService`, dan merekonsiliasi status login
  item dengan service setiap dimuat.
- Implementasi asli `SMAppServiceLoginItems` memakai `SMAppService.mainApp`; error register
  ditampilkan di jendela settings, toggle dikembalikan agar UI tidak berbohong.
- `EngineController` restart timer hanya saat interval berubah (`applySettings` guard),
  perubahan lain tidak mengganggu timer yang berjalan.
- Restore mengembalikan interval 1.0 dtk dan launch-at-login mati (angka Ship-07).
- Belum terverifikasi di Mac: `swift test` dan toggle login item asli (tidak bisa build Swift
  di VM Linux ini) — mohon dijalankan di Mac sebelum merge.
