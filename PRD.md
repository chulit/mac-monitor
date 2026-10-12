# Ultimate Mac Monitor
## Product Requirements Document (PRD)

**Versi:** 0.1  
**Status:** Draft untuk validasi teknis  
**Platform:** macOS 13 Ventura dan lebih baru  
**Model distribusi:** Unduhan langsung dari situs resmi  
**Model bisnis:** Gratis, closed source  
**Prinsip utama:** Local-first, privacy-first, evidence-first

---

## 1. Ringkasan Produk

Ultimate Mac Monitor adalah aplikasi monitoring sistem untuk macOS yang membantu pengguna memahami kondisi Mac, mendeteksi anomali, mengidentifikasi proses yang relevan, dan menyelidiki kejadian berdasarkan data historis.

Produk ini bukan sekadar dashboard CPU dan RAM. Tujuan utamanya adalah menghubungkan empat hal:

1. **Monitoring:** mengumpulkan metrik sistem dan proses.
2. **Detection:** mengenali kondisi tidak normal berdasarkan aturan teknis dan baseline lokal.
3. **Investigation:** menyajikan timeline kejadian beserta metrik dan proses yang relevan.
4. **Explanation:** membantu pengguna memahami bukti, kemungkinan penyebab, serta keterbatasan data.

Semua data monitoring tetap lokal. Aplikasi tidak mengunggah data monitoring atau telemetry penggunaan kepada server. Fitur AI menggunakan kemampuan on-device yang kompatibel; perangkat yang tidak mendukung AI tetap mendapatkan fungsi monitoring inti.

## 2. Visi dan positioning

**Visi:** menjadi aplikasi monitoring Mac yang tidak hanya menunjukkan apa yang terjadi, tetapi membantu pengguna memahami kapan, bagaimana, dan dalam konteks apa masalah muncul.

### Prinsip produk

- **Evidence-first:** kesimpulan harus dapat ditelusuri ke data.
- **Local-first:** data monitoring diproses dan disimpan secara lokal.
- **Low overhead:** monitoring tidak boleh menjadi sumber masalah baru.
- **Adaptive:** intensitas monitoring mengikuti kebutuhan dan anggaran sumber daya.
- **Transparent:** pengguna mengetahui ketika kualitas observasi menurun.
- **Safe by default:** tidak menjalankan tindakan sistem secara otomatis berdasarkan rekomendasi AI.
- **Progressive disclosure:** UI sederhana pada penggunaan normal, lebih detail ketika diperlukan.

## 3. Target pengguna

Produk ditujukan kepada semua pengguna Mac sejak awal, dengan kebutuhan yang beragam:

- Pengguna umum yang ingin mengetahui kondisi Mac.
- Pengguna produktivitas yang mengalami perlambatan atau penggunaan sumber daya tinggi.
- Developer yang ingin memahami proses dan perilaku sistem.
- Power user yang membutuhkan histori, metrik detail, dan investigasi insiden.

Pengalaman dasar harus mudah dipahami pengguna umum, sementara detail lanjutan tersedia tanpa membuat dashboard utama terlalu padat.

## 4. Tujuan produk

### Goals

1. Menampilkan kondisi sistem dan proses secara konsisten.
2. Mendeteksi anomali melalui kombinasi aturan teknis, baseline, dan durasi kejadian.
3. Membantu pengguna menyelidiki incident melalui timeline terintegrasi.
4. Menjaga overhead melalui sampling adaptif dan batas sumber daya.
5. Mempertahankan histori berguna dengan retensi adaptif.
6. Mendukung ekspor dan impor incident tanpa mencampur data arsip dengan histori monitoring aktif.
7. Menyediakan penjelasan berbasis bukti melalui AI lokal pada perangkat kompatibel.

### Non-goals untuk MVP

- Mengendalikan sistem secara otomatis menggunakan AI.
- Mengunggah metrik atau histori monitoring ke cloud.
- Menjamin seluruh metrik hardware tersedia di setiap model Mac.
- Menjamin AI dapat mengidentifikasi penyebab pasti setiap masalah.
- Menjadikan semua fitur lanjutan setara prioritas dengan pengalaman investigasi inti.

## 5. Ruang lingkup MVP

MVP berfokus pada satu perjalanan pengguna yang lengkap: **mendeteksi anomali, menemukan proses relevan, menyelidiki bukti, dan menyimpan hasil investigasi.**

### Fitur wajib

| Area | Kebutuhan MVP |
|---|---|
| System monitoring | Metrik inti dengan timestamp dan status ketersediaan |
| Process monitoring | Daftar proses dan hierarki parent-child |
| Anomaly detection | Aturan teknis, durasi, dan baseline lokal |
| Incident management | Membuat dan menyimpan incident |
| Investigation timeline | Metrik tersinkronisasi dan penanda kejadian |
| Process attribution | Menampilkan proses yang relevan berdasarkan bukti |
| Adaptive sampling | Menyesuaikan intensitas dengan kebutuhan dan anggaran |
| Historical data | Retensi detail dan ringkasan adaptif |
| Incident archive | Ekspor paket incident dan impor sebagai arsip terpisah |
| Privacy | Penyimpanan lokal tanpa telemetry monitoring |

### Fitur lanjutan

Fitur berikut tetap berada dalam arah produk, tetapi tidak boleh menunda penyelesaian alur investigasi inti:

- Smart alerts dan notifikasi tingkat keparahan.
- Hardware sensors yang terbukti dapat diakses.
- Menu bar monitoring yang kaya tetapi ringan.
- Desktop widgets.
- Penjelasan AI lokal.
- Perbandingan incident historis dan baseline.

Urutan final implementasi ditentukan berdasarkan kelayakan teknis, dependensi, dan kriteria rilis.

## 6. Core user journey

### A. Monitoring normal

1. Aplikasi memulai pengumpulan metrik yang tersedia.
2. Sampling disesuaikan dengan mode monitoring.
3. Data ditampilkan pada dashboard dan komponen terkait.
4. Histori disimpan sesuai kebijakan retensi.
5. Baseline dipelajari dari sampel yang memenuhi kriteria normal.

### B. Deteksi anomali

1. Aturan teknis mengevaluasi kondisi kritis.
2. Baseline lokal mendeteksi penyimpangan kontekstual ketika data mencukupi.
3. Durasi, pengulangan, dan konteks menentukan tingkat keparahan.
4. Aplikasi membuat atau memperbarui incident.
5. Notifikasi dikendalikan oleh severity, durasi, pengulangan, cooldown, dan status pemulihan.

### C. Investigasi

1. Pengguna membuka incident.
2. Aplikasi menampilkan timeline dan metrik yang relevan.
3. Proses diurutkan berdasarkan kontribusi anomali yang terukur.
4. Pengguna meninjau perubahan sumber daya, hubungan waktu, dan keterbatasan data.
5. Sampling dapat ditingkatkan sementara jika diperlukan.
6. Ketika batas investigasi tercapai, aplikasi otomatis kembali ke sampling normal.
7. Incident disimpan untuk ditinjau atau diekspor.

### D. Impor incident

1. Pengguna memilih paket incident.
2. Aplikasi memvalidasi format, integritas, dan kompatibilitas.
3. Pengguna meninjau isi paket.
4. Incident dibuka sebagai arsip terpisah.
5. Histori monitoring lokal tidak diubah.

## 7. Persyaratan fungsional

### FR-01 — Monitoring sistem

Aplikasi harus mengumpulkan metrik sistem yang dapat diakses melalui API macOS yang didukung.

Setiap sampel perlu menyimpan timestamp dan informasi kualitas data yang diperlukan untuk interpretasi. Metrik yang tidak tersedia harus ditandai sebagai unavailable, bukan direkayasa atau dianggap nol.

Daftar final metrik dan sumber API ditentukan melalui technical feasibility review.

### FR-02 — Monitoring proses

Aplikasi harus mendukung:

- Identitas proses dan metadata yang tersedia.
- Pengelompokan parent-child dalam process tree.
- Pencarian, filter, expand, dan collapse.
- Penyajian metrik individual dan agregasi subtree secara terpisah.
- Validasi identitas proses sebelum tindakan terminasi.

PID tidak boleh dianggap sebagai identitas permanen karena dapat digunakan kembali oleh proses lain.

### FR-03 — Anomaly detection

Deteksi menggunakan pendekatan hybrid:

- Aturan teknis tetap untuk kondisi kritis.
- Baseline lokal untuk penyimpangan kontekstual.
- Durasi dan pengulangan untuk membedakan kejadian sesaat dari kejadian yang bertahan.
- Hysteresis dan cooldown untuk menghindari alert berulang.

Baseline tidak boleh menonaktifkan aturan kritis. Jika baseline belum cukup matang, deteksi berbasis aturan tetap berjalan.

### FR-04 — Baseline management

Baseline harus:

- Dipelajari secara otomatis dari sampel yang dinilai normal.
- Mengecualikan incident dan sampel anomali yang diketahui.
- Memiliki kandidat baseline dan baseline aktif.
- Diperbarui hanya setelah memenuhi kriteria validasi.
- Memiliki status yang terlihat: Learning, Limited, Stable, atau Stale.
- Mencatat riwayat perubahan, waktu, alasan, versi algoritma, dan jumlah sampel yang memenuhi syarat.

Jika terjadi perubahan besar pada sistem, hanya baseline metrik terdampak yang perlu dikalibrasi ulang.

### FR-05 — Incident investigation

Setiap incident harus menghubungkan:

- Waktu mulai, puncak, dan pemulihan bila dapat ditentukan.
- Metrik terkait pada sumbu waktu yang tersinkronisasi.
- Penanda event dan perubahan status monitoring.
- Proses yang relevan berdasarkan bukti.
- Sampel yang hilang atau keterbatasan akses.
- Versi aturan dan baseline yang digunakan.

Ranking proses harus menjelaskan alasan relevansinya. Hubungan waktu atau parent-child tidak boleh otomatis dinyatakan sebagai sebab-akibat.

### FR-06 — Smart alerts

Alert mengikuti severity, durasi, dan pengulangan.

Sistem harus mendukung:

- Cooldown dan deduplikasi alert.
- Pembaruan incident yang masih aktif.
- Deteksi pemulihan.
- Pencegahan notifikasi berulang untuk kondisi yang sama.
- Pembedaan antara kondisi normal, anomali aktif, dan observasi yang terbatas.

### FR-07 — Process control

Terminasi proses biasa memerlukan konfirmasi pengguna.

Jika proses tidak berhenti, aplikasi memverifikasi status dan identitas proses sebelum menawarkan Force Quit dengan konfirmasi kedua. Kegagalan akibat izin atau perlindungan sistem harus dijelaskan secara akurat.

Tidak ada terminasi proses otomatis berdasarkan hasil AI. Helper berprivilege, jika benar-benar diperlukan, harus mengikuti prinsip least privilege dan memiliki mekanisme instalasi serta penghapusan yang transparan.

### FR-08 — Adaptive monitoring

Sampling menyesuaikan kebutuhan dan anggaran sumber daya.

Prioritas degradasi:

1. Kurangi pekerjaan nonkritis terlebih dahulu.
2. Pertahankan minimum sampling untuk deteksi kritis.
3. Catat interval sampling aktual.
4. Gunakan hysteresis untuk menghindari perubahan mode yang terlalu sering.
5. Pulihkan kualitas secara bertahap ketika kondisi membaik.

Jika penurunan kualitas memengaruhi grafik, deteksi, atau investigasi, UI harus menampilkan indikator kontekstual beserta alasan dan metrik terdampak.

### FR-09 — High-detail investigation mode

Pengguna dapat meminta sampling lebih detail untuk sesi investigasi.

Mode ini harus:

- Memiliki batas durasi dan anggaran overhead.
- Menampilkan status dan waktu tersisa.
- Memberi peringatan sebelum berakhir.
- Tidak melampaui batas keselamatan yang tervalidasi.
- Berakhir otomatis saat batas tercapai.
- Mengembalikan sampling ke mode normal.
- Mencatat transisi pada timeline.

Aplikasi tidak boleh memperpanjang sesi secara diam-diam.

### FR-10 — Historical retention

Retensi menggunakan strategi adaptif:

- Data detail dipertahankan untuk periode pendek.
- Data lama diringkas untuk tren jangka panjang.
- Incident kritis mendapat retensi khusus untuk periode yang ditentukan.
- Pengguna dapat menyematkan incident lain.
- Kuota penyimpanan membatasi pertumbuhan histori.

Ringkasan perlu mempertahankan informasi seperti rentang waktu, jumlah sampel, minimum, maksimum, rata-rata, variasi, durasi ambang terlampaui, dan event penting jika tersedia.

Ketika kuota mendekati batas, sampel detail lama dapat diringkas otomatis sambil mempertahankan metadata dan ringkasan incident. Incident terlindungi tidak boleh dihapus diam-diam.

### FR-11 — Incident export

Aplikasi harus mengekspor satu paket incident berversi yang dapat diimpor kembali.

Paket mencakup:

- Manifest dan identitas paket.
- Timeline dan sampel yang tersedia.
- Metadata incident dan proses yang dipilih.
- Ringkasan.
- Versi skema, aturan deteksi, dan baseline yang relevan.
- Penanda celah data dan interval sampling aktual.
- Informasi integritas paket.

Pengguna harus dapat mengecualikan metadata sensitif sebelum ekspor.

### FR-12 — Incident import

Paket yang diimpor menjadi arsip terpisah dan tidak mengubah histori monitoring lokal.

Sistem harus memvalidasi paket, mendeteksi duplikasi, memeriksa kompatibilitas versi, dan menampilkan pratinjau sebelum impor.

Paket tidak boleh menjalankan kode atau perintah. Migrasi dilakukan pada salinan internal, bukan dengan mengubah file asli.

Analisis ulang menggunakan algoritma baru harus dibedakan dari hasil asli paket.

### FR-13 — Local AI explanation

Pada perangkat yang kompatibel, AI lokal dapat membantu menjelaskan bukti dan menyusun rekomendasi.

AI hanya boleh menggunakan data yang tersedia dan hasil dari evidence/rules engine. Output harus membedakan:

- Fakta yang terukur.
- Korelasi waktu.
- Hipotesis penyebab.
- Tingkat ketidakpastian.
- Data yang tidak tersedia.

AI tidak boleh mengarang metrik, menjamin sebab-akibat tanpa bukti, atau menjalankan tindakan sistem.

Pada perangkat yang tidak kompatibel, monitoring inti tetap berfungsi tanpa cloud fallback.

## 8. Arsitektur konseptual

Arsitektur logis yang disarankan:

1. **Monitoring Engine** — mengumpulkan metrik sistem dan proses.
2. **Sampling Scheduler** — mengatur frekuensi berdasarkan prioritas, mode, dan anggaran.
3. **Local Storage** — menyimpan sampel, histori, baseline, dan incident.
4. **Detection Engine** — menjalankan aturan teknis, baseline, dan evaluasi durasi.
5. **Evidence & Attribution Engine** — menyusun bukti serta relevansi proses.
6. **Incident Manager** — mengelola timeline, retensi, ekspor, dan impor.
7. **Local AI Layer** — menginterpretasikan bukti secara opsional.
8. **Presentation Layer** — dashboard, process tree, timeline, menu bar, dan alert.

Komponen harus menggunakan snapshot bersama agar dashboard, menu bar, widget, dan investigasi tidak melakukan polling identik secara terpisah.

Teknologi implementasi final—termasuk bahasa, framework UI, mekanisme penyimpanan, dan penggunaan helper—ditentukan setelah validasi teknis.

## 9. Persyaratan UI/UX

- Gunakan bahasa visual native macOS yang modern dan konsisten.
- Pada macOS 26+, gunakan Liquid Glass secara selektif sesuai pola platform.
- Pada macOS 13–25, gunakan material native yang sesuai tanpa meniru efek kaca secara berlebihan.
- Utamakan hierarki visual dan keterbacaan, bukan dekorasi.
- Dashboard normal harus ringkas; detail lanjutan muncul saat dibutuhkan.
- Timeline investigasi memakai satu sumbu waktu dan tooltip yang tersinkronisasi.
- Status data unavailable dan reduced monitoring harus terlihat pada konteks yang relevan.
- Tindakan berisiko memiliki konfirmasi yang proporsional.
- Status monitoring tidak boleh disamarkan sebagai status kesehatan sistem.

## 10. Privasi dan keamanan

- Data monitoring diproses dan disimpan lokal.
- Tidak ada telemetry monitoring yang diunggah.
- Tidak ada cloud AI fallback.
- Akses data mengikuti izin macOS dan prinsip least privilege.
- Helper berprivilege, bila diperlukan, hanya menyediakan operasi sempit yang terdefinisi.
- Paket incident diperiksa sebelum diimpor.
- Ekspor sensitif memerlukan tindakan eksplisit.
- Pembaruan aplikasi dapat mengakses jaringan, tetapi tidak boleh mengunggah data monitoring.
- Distribusi langsung harus menggunakan code signing, hardened runtime, notarization, dan mekanisme pembaruan yang aman.

## 11. Persyaratan nonfungsional

### Performa

Anggaran harus bertingkat untuk:

- Idle monitoring.
- Monitoring normal.
- Investigasi aktif.

Setiap tingkat memiliki batas CPU, memori, energi, dan aktivitas disk yang akan ditentukan melalui benchmark.

### Reliabilitas

- Data hilang harus ditandai, bukan diisi dengan nilai fiktif.
- Perubahan sampling harus dapat ditelusuri.
- Kegagalan penyimpanan atau impor harus dapat dipulihkan dengan aman.
- Histori lokal tidak boleh rusak akibat impor paket.

### Kompatibilitas

Target awal adalah macOS 13 Ventura dan lebih baru. Matriks dukungan Apple Silicon dan Intel harus ditentukan berdasarkan kelayakan API dan hasil pengujian.

Fitur hardware dan AI dapat berbeda berdasarkan perangkat. Perbedaan tersebut harus dinyatakan secara eksplisit.

## 12. Acceptance criteria dan release gates

Rilis tidak boleh hanya didasarkan pada selesainya implementasi fitur.

### Detection quality

- Skenario sintetis dapat direproduksi.
- Kondisi kritis tetap terdeteksi ketika baseline belum matang.
- Cooldown, hysteresis, dan recovery bekerja sesuai spesifikasi.
- False positive dan false negative diukur pada kumpulan skenario uji yang ditentukan.

### Investigation quality

- Timeline tersinkronisasi dengan timestamp yang benar.
- Ranking proses menyertakan alasan berbasis bukti.
- PID reuse tidak menyebabkan tindakan pada proses yang salah.
- Celah sampling dan keterbatasan metrik ditampilkan dengan benar.

### Overhead

- CPU, memori, energi, dan disk writes diukur pada ketiga tingkat monitoring.
- Adaptive degradation bekerja ketika anggaran terlampaui.
- Pemulihan sampling berlangsung sesuai kebijakan.
- Monitoring tidak menimbulkan overhead yang melampaui batas rilis.

### Data integrity

- Retensi adaptif mempertahankan statistik dan metadata yang ditentukan.
- Incident terlindungi tidak dihapus diam-diam.
- Paket incident lolos validasi integritas dan kompatibilitas.
- Impor tidak mengubah histori monitoring lokal.

### Security and privacy

- Tidak ada unggahan data monitoring.
- Tidak ada tindakan sistem otomatis dari AI.
- Paket impor tidak dapat mengeksekusi kode.
- Helper, jika ada, diuji terhadap batas hak akses dan jalur kegagalan.

Ambang numerik setiap kriteria harus ditetapkan sebelum release candidate, bukan setelah hasil pengujian diketahui.

## 13. Rencana validasi

1. **Technical feasibility spike:** verifikasi API macOS, izin proses, sensor, dan ketersediaan AI lokal.
2. **Monitoring prototype:** ukur overhead dan kestabilan sampling.
3. **Synthetic anomaly suite:** uji kondisi normal, lonjakan singkat, tekanan berkepanjangan, data hilang, dan perubahan baseline.
4. **Investigation prototype:** validasi timeline dan atribusi proses.
5. **Storage and archive tests:** uji retensi, kuota penuh, paket rusak, paket duplikat, dan kompatibilitas versi.
6. **Release candidate:** jalankan seluruh release gates pada matriks Mac dan macOS yang didukung.

Feedback pengguna setelah rilis boleh membantu evaluasi, tetapi harus tetap lokal secara default dan tidak dianggap sebagai ground truth tanpa validasi.

## 14. Risiko utama

| Risiko | Mitigasi |
|---|---|
| API macOS tidak menyediakan metrik tertentu | Validasi lebih awal, gunakan status unavailable |
| False positive pada anomaly detection | Durasi, hysteresis, baseline terjaga, regression tests |
| Overhead meningkat saat investigasi | Anggaran bertingkat dan batas sesi |
| Baseline tercemar anomali | Kandidat baseline, validasi, pengecualian sampel anomali |
| Atribusi proses dianggap sebagai sebab-akibat | Bukti eksplisit, label relevansi, ketidakpastian |
| Paket incident terlalu besar | Retensi adaptif dan ringkasan |
| Paket berisi metadata sensitif | Pratinjau dan pengecualian metadata |
| Perubahan versi merusak arsip lama | Versioned schema dan migrasi yang diuji |

## 15. Open decisions

Hal berikut belum boleh dianggap sebagai keputusan implementasi final:

1. Daftar metrik dan API yang benar-benar tersedia pada tiap versi macOS.
2. Bahasa dan framework implementasi.
3. Apakah helper berprivilege diperlukan untuk metrik tertentu.
4. Batas numerik CPU, memori, energi, sampling, dan penyimpanan.
5. Durasi retensi detail serta periode khusus incident kritis.
6. Format paket incident final dan kebijakan kompatibilitas.
7. Ambang deteksi awal dan acceptance criteria numerik.
8. Daftar perangkat yang mendukung AI lokal dan fallback UX-nya.
9. Detail lisensi, update signing, dan prosedur pemulihan pembaruan.

## 16. Definisi keberhasilan MVP

MVP dianggap siap dirilis ketika pengguna dapat:

1. Melihat kondisi sistem dan proses dengan status data yang jujur.
2. Menerima deteksi anomali yang tervalidasi.
3. Membuka incident dan menelusuri bukti pada timeline.
4. Mengidentifikasi proses yang relevan tanpa klaim kausalitas yang tidak terbukti.
5. Meningkatkan detail monitoring untuk investigasi dan kembali ke mode normal secara otomatis.
6. Meninjau histori, mengekspor incident, dan mengimpornya sebagai arsip terpisah.
7. Menggunakan monitoring inti tanpa AI dan tanpa mengunggah data monitoring.

**Prinsip rilis:** kualitas alur investigasi, integritas bukti, privasi, dan overhead lebih penting daripada banyaknya fitur yang sekadar terlihat lengkap.
