---
description: Mengelompokkan, memverifikasi, dan membuat commit perubahan secara konsisten.
---

# Commit Convention

Gunakan workflow ini hanya saat user meminta commit atau delivery perubahan.

## Steps

1. Cek semua perubahan:
   - `git status --short`
   - `git diff --name-only`
   - `git diff`
2. Kelompokkan perubahan berdasarkan domain/fitur/file yang saling terkait. Jangan campur perubahan yang tidak relevan.
3. Untuk setiap kelompok:
   - stage hanya file yang relevan;
   - gunakan Conventional Commit dengan scope: `<type>(<scope>): <judul>`;
   - gunakan subject deskriptif, lowercase, maksimal 100 karakter;
   - gunakan body bullet points yang menjelaskan perubahan utama, file/area, dan dampak perilaku;
   - sisakan satu baris kosong setelah subject dan batasi tiap baris body maksimal 120 karakter.
4. Gunakan Bahasa Indonesia pada subject/body, kecuali `type` dan `scope`.
5. Jika ada file yang relevansinya meragukan, jelaskan pengelompokannya sebelum commit.
6. Jika commit hook gagal, perbaiki penyebab atau message lalu ulangi. Dilarang menggunakan `--no-verify`.
   6a. Jangan tambahkan trailer `Co-Authored-By: Claude ...` (atau sejenisnya) di commit message.
7. Sebelum commit, pastikan tidak ada `console.log`, jalankan `composer format:php:check` untuk perubahan PHP,
   lalu cek `git diff --check`.
8. Setelah semua commit selesai, pastikan `git status --short` kosong dan laporkan:
   - hash commit;
   - subject setiap commit;
   - ringkasan body setiap commit.
