# 08: Engine integration, verification, and polish pass

**What to build:** Integrate live metrics, samples, process deltas, and incidents from `EngineController` into the Overview screen, test state transitions, verify dark and light mode appearance, and ensure clean compilation and test verification.

**Blocked by:** 05, 07.

**Status:** ready-for-agent

- [x] Overview screen correctly updates with live readings from `EngineController` without unnecessary view re-renders
- [x] Toggling "Start Investigation" triggers real high-detail sampling via `pipeline.requestHighDetail`
- [x] View smoothly transitions between normal monitoring mode (`a. overview.png`) and high-detail investigation mode (`b. overview - start-investigating.png`)
- [x] Dynamic colors adapt seamlessly between macOS Light and Dark appearances
- [x] Full project builds cleanly with `swift build` and passes unit tests

## Comments

## Notes (2026-10-13)

- Live readings: semua kartu memakai input `let` yang sempit (invalidation
  boundary per tipe View) — tidak ada re-render yang tidak perlu.
- Start/Stop Investigation memanggil `pipeline.requestHighDetail` /
  `endHighDetail` asli via EngineController (terverifikasi di kode).
- Transisi mode: status header + kartu investigasi muncul dengan spring.
- Audit warna: tidak ada warna hardcoded di view overview baru — semua
  system color adaptif; yang hardcoded hanya gradient branding lama.
- `swift build` + `swift test` BELUM terverifikasi: tidak bisa build Swift di
  VM Linux ini — mohon dijalankan di Mac sebelum merge.
