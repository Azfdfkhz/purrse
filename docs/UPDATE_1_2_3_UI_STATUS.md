# PurssApp Update 1.2.3 — Perombakan UI, Navbar, Beranda, Laporan, Drive

> Belum dikompilasi (sandbox tanpa Flutter SDK / akses pub.dev). Jalankan dulu:
> `flutter pub get && flutter analyze && flutter run`.

## UI
- Palet baru: latar greige lembut, kartu putih, **tanpa outline hitam tebal** (diganti garis 1 px sangat halus + bayangan lembut). Berlaku di kartu, chip filter, kolom input, sheet tambah pengeluaran, kartu profil, splash.
- Font diganti ke Inter (lebih rapi dan mudah dibaca).

## Navbar
- Pil melayang: tab aktif = pil hitam berisi ikon + label, tab lain ikon saja. Tombol (+) bulat terpisah di kanan.

## Beranda (mengikuti desain 1)
- Sapaan besar, dua kartu bertumpuk (bulan lalu mengintip di belakang), tombol "Lihat laporan" di lekukan kartu, 4 aksi cepat (Tambah, Transaksi, Laporan, Kategori), ringkasan per kategori, daftar pengeluaran terbaru + "Lihat semua". Tarik untuk muat ulang.

## Laporan (mengikuti desain 2)
- Harian: awal tampil **strip satu minggu** (geser kiri/kanan atau tombol panah); ketuk chip bulan untuk membuka **kalender sebulan penuh**. Daftar pengeluaran hari terpilih + baris putus-putus untuk menambah.
- Bulanan: 12 pil bulan, total + perbandingan bulan lalu, grafik setahun, rincian per kategori.
- Mode tampilan "Calendar/Data" lama dihapus (digantikan strip minggu/kalender bulan).

## Google Drive — hubungkan sekali, menetap
Penyebab sebelumnya: pemulihan sesi dipanggil dua kali bersamaan (main.dart + halaman Backup) sehingga salah satunya gagal, dan UI menganggap Drive terputus. Izin Drive juga baru diminta terpisah setelah login.
- Status "terhubung" + email disimpan permanen dan dibaca saat start; halaman Backup tidak lagi menampilkan "Hubungkan" sebelum sesi pulih.
- `restoreSession()` satu-jalur (semua pemanggil berbagi satu proses) + 3x percobaan; gagal/offline tidak menghapus status terhubung.
- Login meminta izin Drive sekaligus (`scopeHint`), jadi persetujuan hanya sekali.
- Backup/restore/pratinjau memulihkan sesi dulu, hanya menampilkan login bila benar-benar perlu. Status hanya dihapus saat pengguna menekan "Putuskan Google Drive".
