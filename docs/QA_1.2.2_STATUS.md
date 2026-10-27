# Status Update 1.2.2 (hasil kerja di source; BELUM dikompilasi/diuji di perangkat)

Jalankan dulu: `flutter pub get`, `flutter analyze`, lalu uji manual Android/iOS.

## Sudah diimplementasikan di source
- Token warna dinamis (Light/Dark), mode Sistem/Terang/Gelap tersimpan, teks otomatis kontras (onColor/onPastel).
- Laporan: tombol Hari ini/Bulan ini, tahun tampil, cincin penanda hari ini.
- Profil dikelompokkan; halaman Notifikasi; lonceng membuka pengaturan notifikasi.
- Notifikasi lokal terjadwal (harian, mingguan, backup), izin, zona waktu, batal saat logout, deep link (termasuk saat app tertutup).
- Backup: status Drive dibedakan dari status backup, preview sebelum restore, salinan pengaman + batalkan restore, backup otomatis (debounce, antrean tahan restart, retry bertahap).
- Form transaksi: validasi inline, tombol simpan tidak tertutup keyboard.

## Belum / di luar jangkauan source
- Migrasi ke Supabase Auth + sinkronisasi per auth.uid() + RLS (butuh keputusan dan konfigurasi server).
- Push notification FCM (butuh backend).
- Redesain tata letak total layar Transaksi, Profil, Auth (baru token/kontras).
- Seluruh checklist QA bagian 8 (perlu uji manual di perangkat), termasuk font besar dan layar kecil.
