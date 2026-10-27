# PurssApp 1.2.1 — Redesain UI/UX (playful, minimalis, modern)

Acuan: 3 gambar referensi pengguna + bagian 10 dokumen evaluasi.
Belum dikompilasi/diuji di perangkat (sandbox tanpa Flutter SDK). Semua kriteria 10.6 BELUM dicentang.

## Bahasa desain
- **Krem hangat** sebagai latar, **hitam tinta** (#1F1B24) untuk tombol, navbar, outline, dan teks utama.
- **Outline tinta tebal** (1,5 px) pada kartu utama + sudut sangat membulat (gaya referensi 2).
- **Kartu saldo gelap** + tombol pil putih/aksen (referensi 1); **navbar pil hitam melayang** dengan item aktif putih dan tombol (+) berwarna aksen.
- **Tombol pil hitam** teks putih (referensi 3), bar grafik berbentuk pil beroutline.
- Warna aksen pilihan pengguna (Profil > Tampilan) tetap berlaku: dipakai pada tombol (+), chip bulan, grafik, dekorasi kartu saldo.
- `textGrey` diperbaiki (sebelumnya hampir hitam) menjadi abu terbaca (kontras >= 4,5:1 di atas putih).

## Komponen bersama (`lib/widgets/ui_kit.dart`)
`Pressable` (efek tekan 120 ms), `FadeSlideIn` (fade+geser ~220 ms), `InkCard`, `InkButton` (normal/loading/disabled), `motion()` yang otomatis 0 ms jika pengguna mengaktifkan "kurangi gerakan".

## Layar yang diubah
Beranda (kartu saldo gelap, jumlah transaksi, outline kartu, item daftar), navbar, form tambah/edit (sheet beroutline, kategori 52 px dengan animasi pilih, tombol pil), Laporan (pill, grafik batang pil, empty state), Transaksi (kartu & chip), Auth (tombol & input), Splash (animasi masuk), tema global (snackbar, tombol, input, bottom sheet).
Animasi: transisi tab (fade 220 ms), tekan tombol, pilih kategori, snackbar "Pengeluaran tersimpan ✓". Penyimpanan transaksi tidak menunggu animasi.

## Belum dikerjakan
- Audit layar Profil/Akun, Tampilan, Kelola Kategori, Backup & Restore secara detail (hanya mewarisi token/tema).
- Skeleton loading, animasi grafik, label nilai di atas batang.
- Pengujian overflow di layar kecil, font sistem besar, dan performa di perangkat low-end.
- Regresi fungsi (tanggal, edit/hapus, Drive) setelah perubahan UI.
