# Purrse Update 1.2.5 — Tour guide, animasi, palet warna

> Belum dikompilasi (sandbox tanpa Flutter SDK). Jalankan dulu:
> `flutter pub get && flutter analyze && flutter run`.

## 1. Tour guide (lib/widgets/tour_guide.dart)
- Sebelumnya hanya menyorot navbar. Sekarang 19 langkah lintas tab: navbar, tombol +
  (isi formulir), Beranda (header, kartu total, aksi cepat, per kategori, terbaru),
  Transaksi (filter, kartu), Laporan (Harian/Bulanan, kalender, tambah, strip minggu),
  Akun (profil, preferensi, data, keamanan), penutup.
- Tour berpindah tab sendiri (`TourGuide.tabSelector` diisi NavbarShell) dan menggulir
  halaman ke elemen yang disorot.
- Langkah opsional dilewati otomatis bila elemennya tidak ada (data kosong / mode lain aktif).
- Muncul sekali lagi untuk semua pengguna (kunci `purrse_tour_done_125`); bisa diulang dari
  Akun > Panduan Aplikasi.
- Kunci sorotan baru ada di `tour_keys.dart` dan dipasang di tiap layar lewat `KeyedSubtree`.

## 2. Animasi
- Transisi halaman global (geser + pudar), pindah tab lebih halus + efek kedalaman halaman.
- Navbar: lebar tab dianimasikan, label memudar, tombol + dengan efek tekan pegas.
- Beranda: total menghitung naik, bilah kategori tumbuh, daftar terbaru muncul bertahap.
- Laporan: pil Harian/Bulanan bergeser, isi mode memudar, kartu harian bertahap.
- Transaksi & Akun: item muncul bertahap. Bottom sheet tambah pengeluaran lebih halus.
- Tour: sorotan berpindah mulus + denyut, kartu geser searah navigasi, progres animasi.
- Semua menghormati pengaturan sistem "kurangi gerakan".

## 3. Warna
- Burgundy ditambahkan (`AppColors.burgundy*`): pilihan aksen "Burgundy" dan "Burgundy Lembut",
  tombol +, titik tanggal berpengeluaran di Laporan, aksen tour.
- Palet diselaraskan: latar/permukaan greige-rose hangat, `ink` dan `inkInverse` (terang)
  disatukan, pastel dibuat lebih "dusty" dengan kecerahan serupa, kartu belakang Beranda
  kini nada tonal dari warna aksen (tidak lagi oranye).
- Kategori yang sudah tersimpan tidak diubah; kategori bawaan akun baru memakai palet baru.
- Versi di pubspec tidak diubah.

## Perbaikan: tour macet di Transaksi
- Pencarian elemen sorotan tidak punya batas waktu, sehingga langkah opsional "Kartu transaksi"
  menunggu selamanya bila belum ada transaksi berfoto. Kini maksimal ±1,6 dtk, lalu langkah dilewati.
- Pindah tab, pengguliran, dan penantian frame juga diberi batas waktu agar tour tidak bisa macet.

## Perbaikan: swipe antar tab terasa berat
- Efek pudar+skala halaman per frame dihapus (memaksa gambar ulang seluruh halaman tiap frame);
  tiap halaman kini dibungkus RepaintBoundary sehingga digeser sebagai gambar jadi.
- Foto di kartu Transaksi didekode 800 px (sebelumnya resolusi penuh kamera).
