# Update 1.2.6 — Identitas Purrse, warna dinamis, animasi, notifikasi lucu

## 1. Warna mengikuti pilihan user
- Burgundy bukan lagi warna dasar. Warna bawaan = ungu Purrse `#6A4FCF`.
- Burgundy kini hanya satu opsi di **Profil > Tampilan** (`ThemeController.presets`).
- Semua token (`ink`, `inkInverse`, `soft`, `background`, `surface`, `surfaceVariant`, `border`) diturunkan dari
  satu warna pilihan (`AppColors.seed`) di `lib/theme/app_colors.dart`, untuk mode terang dan gelap.
- Warna bawaan memakai palet brand persis: Primary `#6A4FCF`, Accent `#F79B4B`, Secondary `#EADFFF`,
  Background `#FFF8F0`, Text `#2E1F3A`.
- Pengguna lama: pilihan pastel lama dipetakan ke warna dengan rona serupa (`ThemeController._legacy`),
  termasuk saat restore backup lama.

## 2. Logo & identitas (semua platform)
- Aset dipotong dari PNG showcase: `assets/images/brand/` (mark, wordmark, sparkle, garis semangat, ikon, lockup horizontal).
- Ikon aplikasi: Android (legacy + adaptive + monochrome), iOS (semua ukuran, tanpa alpha), macOS, Windows `.ico`, web (any + maskable, favicon).
- Splash: Android (`launch_background`, Android 12+), iOS (`LaunchScreen`), Flutter (`SplashScreen`).
- Nama tampil: **Purrse** (Android label, iOS, web manifest/title, jendela Windows/Linux).
- Ikon notifikasi: siluet putih `ic_stat_purrse` + ikon besar `ic_notif_large`, warna ungu Purrse.
- Catatan: sumber logo hanya PNG kecil (~320 px). Aset sudah diperbesar & dipertajam, tapi master vektor (SVG)
  dari desainer tetap disarankan untuk hasil terbaik di ukuran besar.

## 3. Animasi
- `PurrseMark` / `PurrseLogo` (`lib/widgets/purrse_logo.dart`): masuk memantul, napas + goyang idle,
  kilau berkedip, garis semangat bergetar, ketuk = lompat + goyang.
- Transisi halaman Purrse (Android/desktop; iOS tetap native), tombol membal saat dilepas,
  ikon navbar "pop", daftar muncul dengan sedikit membal, snackbar bertema kucing, empty state beranimasi.
- Semua animasi mati bila "kurangi gerakan" aktif.

## 4. Notifikasi lucu
- Pengingat harian **pintar**: dijadwalkan 7 hari ke depan, melewati hari yang sudah ada catatan.
- Nada pesan naik bertahap: belum pernah mencatat → hari ini belum → 2-3 hari → 4+ hari ("kangen").
- Disegarkan saat app dibuka/resume dan setiap pengeluaran ditambah/diubah/dihapus.
- Tanpa nominal uang (aman di lock-screen). Ada tombol **Coba notifikasi lucu** di pengaturan notifikasi.
- Batasan: jika app tidak dibuka lebih dari 7 hari, pengingat berhenti setelah slot terakhir.

## Perlu dicek di perangkat (belum bisa dikompilasi di lingkungan ini)
- `flutter pub get && flutter analyze`, lalu jalankan di Android & iOS.
- Android: uji notifikasi (ikon siluet) dan ikon adaptive.

## 5. Edit / Hapus pengeluaran
- Ketuk pengeluaran di Beranda atau Laporan: muncul popup **Edit** atau **Hapus** (`lib/widgets/expense_actions.dart`).
- Hapus meminta konfirmasi; semua tab dan pengingat harian ikut disegarkan otomatis.

## Perbaikan build
- `purrse_motion.dart`: import `flutter/cupertino.dart` dikembalikan (`CupertinoPageTransitionsBuilder`).
