# Finance App - Perubahan

## 1. Warna utama global
- Warna yang dipilih di Profile > Tampilan sekarang menjadi `ColorScheme.primary` aplikasi.
- Tombol, floating action button, navbar aktif, progress indicator, focus border input, filter chip, dan elemen UI utama mengikuti warna tersebut.
- Warna pilihan tetap tersimpan di `SharedPreferences` dan dimuat saat aplikasi dibuka kembali.
- Warna kategori pengeluaran tetap independen agar setiap kategori tetap mudah dibedakan.

## 2. Menu Transaksi
- Menu Transaksi tidak lagi memakai placeholder.
- Menampilkan foto bukti yang benar-benar diupload user saat membuat pengeluaran.
- Setiap foto menampilkan deskripsi, kategori, tanggal, dan nominal.
- Filter kategori tersedia secara horizontal.
- Filter tanggal memakai date picker.
- Foto dapat dibuka dalam tampilan besar dengan zoom.
- Transaksi dapat dihapus dari menu Transaksi.
- Setelah transaksi baru disimpan, data Beranda dan Transaksi direfresh.
- Foto yang tidak lagi tersedia di path lokal tidak ditampilkan sebagai foto transaksi.

## Menjalankan project

```bash
flutter pub get
flutter run
```

Jika project sebelumnya sudah memiliki build/cache lama, aman untuk menjalankan:

```bash
flutter clean
flutter pub get
flutter run
```
