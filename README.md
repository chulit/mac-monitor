# Ultimate Mac Monitor

Aplikasi monitoring sistem untuk macOS yang **local-first, privacy-first, dan evidence-first**.
Bukan sekadar dashboard CPU/RAM — aplikasi ini menghubungkan **monitoring → deteksi anomali → investigasi → penjelasan berbasis bukti**.

> Platform: macOS 13 Ventura ke atas · Apple Silicon & Intel · Swift + SwiftUI · SwiftPM

---

## Daftar Isi

- [Kenapa aplikasi ini ada](#kenapa-aplikasi-ini-ada)
- [Fitur](#fitur)
- [Tampilan](#tampilan)
- [Arsitektur](#arsitektur)
- [Struktur Proyek](#struktur-proyek)
- [Mulai Cepat](#mulai-cepat)
- [Build & Run](#build--run)
- [Testing](#testing)
- [Pengaturan & Privasi](#pengaturan--privasi)
- [Dokumen Produk](#dokumen-produk)
- [Roadmap](#roadmap)
- [Berkontribusi](#berkontribusi)
- [Lisensi](#lisensi)

---

## Kenapa aplikasi ini ada

Kebanyakan system monitor hanya menjawab *"berapa % sekarang?"*.
Ultimate Mac Monitor menjawab pertanyaan yang lebih penting:

1. **Kapan** masalah mulai, memuncak, dan pulih?
2. **Dalam konteks apa** masalah itu muncul (metrik lain, event, status monitoring)?
3. **Proses mana** yang relevan — lengkap dengan alasan berbasis bukti, bukan klaim sebab-akibat?
4. **Seberapa bisa dipercaya** datanya (gap sampling, metrik unavailable, reduced monitoring)?

Prinsip produk (dari `PRD.md`):

| Prinsip | Artinya |
|---|---|
| Evidence-first | Setiap kesimpulan bisa ditelusuri ke data |
| Local-first | Semua data diproses & disimpan lokal, tanpa upload telemetry |
| Low overhead | Monitoring tidak boleh jadi masalah baru |
| Adaptive | Intensitas sampling mengikuti kebutuhan & anggaran resource |
| Transparent | Penurunan kualitas observasi selalu ditampilkan + alasannya |
| Safe by default | AI tidak mengeksekusi tindakan sistem otomatis |
| Progressive disclosure | UI ringkas saat normal, detail muncul saat dibutuhkan |

---

## Fitur

### Saat ini (MVP track)

- **Dashboard sistem** — kartu metrik CPU, memori, disk, jaringan, suhu, uptime + sparkline & timeline.
- **Process monitor** — daftar proses, pencarian/filter, process tree (parent-child), metrik individual vs agregasi subtree, detail proses + histori.
- **Anomaly detection (hybrid)** — technical rules untuk kondisi kritis + baseline lokal untuk penyimpangan kontekstual, lengkap dengan durasi, recurrence, hysteresis, dan cooldown.
- **Baseline management** — kandidat vs aktif, status Learning / Limited / Stable / Stale, riwayat perubahan tervalidasi.
- **Incident & investigation timeline** — satu sumbu waktu tersinkronisasi: metrik terkait, event marker, perubahan status monitoring, gap sampling.
- **Process attribution** — ranking proses berdasarkan kontribusi terukur + alasan ("relevan karena…"), tanpa klaim kausalitas palsu.
- **Adaptive sampling** — degradasi bertingkat saat over-budget, hysteresis anti-flapping, pemulihan bertahap.
- **High-detail investigation mode** — sampling detail sementara dengan batas durasi + anggaran, auto-stop, tercatat di timeline.
- **History & retention adaptif** — data detail jangka pendek, ringkasan jangka panjang (min/max/avg/variasi/durasi-over-threshold), incident kritis/pinned dilindungi kuota.
- **Incident package (export/import)** — paket berversi berisi manifest, timeline, sampel, metadata, versi schema/rule/baseline, penanda gap, info integritas. Impor dibuka sebagai **arsip terpisah**, tidak mengubah histori lokal.
- **Menu bar + popover cepat** — status ringkas tanpa membuka window utama.

### Lanjutan (tidak menunda alur investigasi inti)

Smart alerts ber-level severity, hardware sensor tambahan yang terbukti accessible, menu bar kaya tapi ringan, desktop widget, penjelasan AI lokal on-device, perbandingan incident historis vs baseline.

Detail kebutuhan lengkap: lihat [`PRD.md`](PRD.md). Glosarium istilah: lihat [`CONTEXT.md`](CONTEXT.md).

---

## Tampilan

> Tambahkan screenshot ke `docs/screenshots/` lalu tautkan di sini.

| Dashboard | Processes | Incident Timeline |
|---|---|---|
| `docs/screenshots/dashboard.png` | `docs/screenshots/processes.png` | `docs/screenshots/incident.png` |

```markdown
![Dashboard](docs/screenshots/dashboard.png)
![Processes](docs/screenshots/processes.png)
![Incident Timeline](docs/screenshots/incident.png)
```

---

## Arsitektur

Arsitektur logis (konseptual, sesuai PRD §8):

```
┌──────────────┐   ┌───────────────────┐   ┌──────────────┐
│   Monitoring │──▶│ Sampling Scheduler │──▶│ Local Storage│
│    Engine    │   │ (adaptive, budget) │   │ (samples,    │
└──────────────┘   └───────────────────┘   │ baseline,    │
       │                                    │ incidents)   │
       ▼                                    └──────────────┘
┌──────────────┐   ┌───────────────────┐           │
│  Detection   │──▶│ Evidence &        │◀──────────┘
│   Engine     │   │ Attribution Engine│
│ (rules +     │   └───────────────────┘
│  baseline)   │           │
└──────────────┘           ▼
                  ┌───────────────────┐   ┌──────────────┐
                  │  Incident Manager │──▶│ Presentation │
                  │ (timeline,retain, │   │ (dashboard,  │
                  │  export/import)   │   │ tree,timeline│
                  └───────────────────┘   │ menubar,alert│
                                          └──────────────┘
                        ┌──────────────┐          ▲
                        │ Local AI     │──────────┘
                        │ Layer (opt.) │
                        └──────────────┘
```

Implementasi nyata di repo:

- **`Sources/MonitoringEngine/`** — domain + logic murni, tanpa SwiftUI: `Sample`, `Observation`, `Pipeline`, `TechnicalRule`, `Baseline`, `Attribution`, `Timeline`, `IncidentCenter`, `HistoryCenter`, `Retention`, `Archive`, kolektor (`HostCollector`, `ProcessCollector`, `NetworkCollector`, `TemperatureCollector`), `Clock`, `SyntheticStream`, `Benchmark`, presentasi data (`Presentation`, `OverviewCards`, `TimelineChart`, …).
- **`Sources/UltimateMacMonitorApp/`** — aplikasi SwiftUI: `MonitorApp`, `AppDelegate`, `EngineController`, `RootView`, `DashboardView`, `ProcessesView`, `IncidentsView`, `HistoryView`, `Settings*`, kartu & chart SwiftUI Charts, menu bar, update checker.
- **`Sources/CPUProbe/`** — probe helper kecil untuk eksperimen CPU.
- Semua permukaan UI (dashboard, menu bar, widget) memakai **snapshot bersama** — tidak polling terpisah.

Keputusan arsitektur tercatat: [`docs/adr/`](docs/adr/).

---

## Struktur Proyek

```
.
├── Package.swift                  # SwiftPM: MonitoringEngine, UltimateMacMonitorApp, CPUProbe
├── Sources/
│   ├── MonitoringEngine/          # Logic inti (testable, tanpa UI)
│   ├── UltimateMacMonitorApp/     # SwiftUI app (window, menubar, settings)
│   └── CPUProbe/                  # Probe eksperimen
├── Tests/MonitoringEngineTests/   # Unit test engine + presentasi
├── packaging/Info.plist           # Info.plist untuk .app bundle
├── scripts/package-app.sh         # Rakit + ad-hoc sign dist/*.app
├── docs/
│   ├── adr/                       # Architecture Decision Records
│   ├── agents/                    # Panduan agen (issue tracker, label, domain)
│   └── plans/                     # Rencana implementasi
├── dist/                          # Output .app lokal (tidak di-commit)
├── PRD.md                         # Spesifikasi produk
├── CONTEXT.md                     # Glosarium satu-konteks
└── AGENTS.md                      # Aturan kerja agen
```

---

## Mulai Cepat

**Syarat:**

- macOS 13+
- Xcode 15+ (atau Swift toolchain 6.0+)
- Swift 6.0 (`swift --version`)

**Clone & build:**

```sh
git clone <repo-url> ultimate-mac-monitor
cd ultimate-mac-monitor
swift build
```

**Jalankan dari Xcode / SwiftPM (mode dev):**

```sh
swift run UltimateMacMonitorApp
```

**Jalankan sebagai .app (menu bar, ikon, bundle proper):**

```sh
./scripts/package-app.sh
open dist/UltimateMacMonitor.app

# Instal + relaunch otomatis:
./scripts/package-app.sh --relaunch
```

> Catatan: `swift run` membangun binary CLI-style — cocok untuk dev cepat.
> Untuk pengalaman penuh macOS (dock icon, menu bar, resources), selalu pakai `scripts/package-app.sh`.

---

## Build & Run

| Perintah | Kegunaan |
|---|---|
| `swift build` | Build debug semua target |
| `swift build -c release` | Build release |
| `swift run UltimateMacMonitorApp` | Run langsung (dev) |
| `swift run CPUProbe` | Jalankan probe CPU eksperimen |
| `./scripts/package-app.sh` | Rakit `dist/UltimateMacMonitor.app` + ad-hoc sign |
| `./scripts/package-app.sh --relaunch` | Copy ke `/Applications`, verifikasi sign, relaunch |

Signing saat ini **ad-hoc untuk run lokal**. Distribution signing (Developer ID + notarization) adalah langkah terpisah sebelum distribusi publik — lihat PRD §10.

---

## Testing

```sh
swift test                        # seluruh suite
swift test --filter MonitoringEngineTests   # modul engine saja
```

Cakupan saat ini (`Tests/MonitoringEngineTests/`): section aplikasi, chart domain, history center, incident center, investigation progress, kartu metrik, header overview, tabel proses, sampling seam, settings, timeline chart.

Sebelum rilis, release gates PRD §12 wajib hijau: detection quality (synthetic suite), investigation quality (sinkronisasi timeline, atribusi, PID-reuse safety), overhead (CPU/memori/energi/disk di 3 tier), data integrity (retensi, paket, impor), dan security/privacy (tanpa upload, tanpa code-exec dari paket impor).

---

## Pengaturan & Privasi

- **100% lokal.** Tidak ada upload metrik monitoring atau telemetry penggunaan. Update aplikasi boleh akses jaringan, tapi tidak pernah mengunggah data monitoring.
- **Tanpa cloud AI fallback.** Fitur AI hanya on-device di perangkat kompatibel; perangkat lain tetap dapat monitoring inti penuh.
- **Data jujur.** Metrik yang tidak tersedia ditandai `unavailable` — tidak pernah diisi nol atau dianggap normal.
- **PID tidak permanen.** Aksi terminasi selalu verifikasi ulang identitas proses (waspada PID reuse), butuh konfirmasi; Force Quit butuh konfirmasi kedua.
- **Ekspor sadar privasi.** Metadata sensitif bisa dikecualikan sebelum ekspor; paket impor divalidasi (format, integritas, kompatibilitas, duplikat) dan tidak pernah mengeksekusi kode.
- **Helper privilege (jika kelak perlu)** mengikuti least-privilege + instal/uninstal transparan.

---

## Dokumen Produk

| Dokumen | Isi |
|---|---|
| [`PRD.md`](PRD.md) | Requirements lengkap v0.1: journey, FR-01…FR-13, UI/UX, NFR, acceptance criteria, risiko |
| [`CONTEXT.md`](CONTEXT.md) | Glosarium kanonis: sample, baseline, incident, alert, timeline, evidence, dsb. |
| [`docs/adr/`](docs/adr/) | Keputusan arsitektur (mis. paket impor dibuka sebagai arsip terpisah) |

Istilah yang dipakai di README ini mengikuti `CONTEXT.md`. Kalau ragu soal makna "incident" vs "alert" vs "event marker", cek ke sana dulu.

---

## Roadmap

- [x] Monitoring engine + kolektor sistem/proses
- [x] Dashboard, process tree, history view (awal)
- [x] Incident center + timeline investigasi (awal)
- [x] Retention adaptif + incident package export/import (awal)
- [ ] Synthetic anomaly suite + release-gate benchmarks
- [ ] Smart alerts (severity, cooldown, dedup, recovery)
- [ ] High-detail investigation mode berbatas anggaran
- [ ] Local AI explanation (on-device, evidence-grounded)
- [ ] Menu bar kaya + desktop widget
- [ ] Distribution: Developer ID signing, notarization, auto-update aman

Status detail per-task: lihat issue tracker di [`.scratch/`](.scratch/) (panduan: `docs/agents/issue-tracker.md`).

---

## Berkontribusi

1. Baca `PRD.md`, `CONTEXT.md`, dan `docs/adr/` sebelum mengubah behavior domain.
2. Ikuti label triase baku: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
3. Logic murni masuk `MonitoringEngine` + unit test; SwiftUI hanya di `UltimateMacMonitorApp`.
4. Jangan samakan *monitoring status* dengan *system health*; jangan nyatakan korelasi waktu sebagai kausalitas.
5. Setiap kesimpulan baru harus bisa ditelusuri ke evidence.

---

## Lisensi

Gratis, closed source — didistribusikan via unduhan langsung dari situs resmi (lihat PRD §10 untuk ketentuan signing & update). Detail lisensi final menyusul sebelum rilis publik.
