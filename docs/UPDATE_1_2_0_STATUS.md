# PurssApp 1.2.0 — Status Pengerjaan

Sandbox tidak punya Flutter SDK / akses pub.dev, jadi kode **belum dikompilasi dan belum diuji di perangkat**.
Jalankan: `flutter pub get && flutter analyze && flutter run`. Semua checklist QA di bawah BELUM dicentang karena belum diuji.

## Sudah dikerjakan (kode ditulis, perlu diuji)
- **Tanggal transaksi**: tanggal kejadian disimpan sebagai `yyyy-MM-dd` (tanpa jam/zona waktu); data lama dimigrasi saat dibaca. `createdAt`/`updatedAt` dipisah dari tanggal kejadian.
- **Kalender -> formulir**: tombol "Tambah di <tanggal>" di Laporan (Hari) dan tombol (+) saat berada di Laporan membawa tanggal yang diketuk pengguna. Navigasi bulan tidak mengubah tanggal transaksi.
- **Edit transaksi** (menu titik tiga di Transaksi); edit tidak mengubah tanggal kecuali pengguna mengubahnya.
- **Nominal**: input rupiah bulat dengan pemisah ribuan, validasi > 0 dan batas atas; tampilan dibulatkan konsisten.
- **Penyimpanan lokal**: operasi baca-ubah-tulis diserialkan (tidak saling menimpa), data rusak satu baris tidak menghapus semua, ID idempoten, hapus = tombstone (siap sinkron), restore backup divalidasi dan tanpa duplikat.
- **Google Drive**: sesi dipulihkan senyap (tidak pilih akun lagi), foto otomatis masuk antrean upload, status (menunggu/mengunggah/berhasil/gagal/perlu hubungkan), retry bertahap + tombol "Coba lagi", anti-duplikat (dicek via ID transaksi di Drive), berhasil hanya setelah Drive mengembalikan ID file, ID file disimpan di transaksi, foto bisa dimuat dari Drive bila file lokal tidak ada, pemutusan koneksi tetap eksplisit di Pengaturan. File tidak dibagikan publik.
- **Password lokal**: PBKDF2-HMAC-SHA256 + salt; password teks biasa lama dimigrasi otomatis saat login.
- **UI**: font < 12 dinaikkan ke 12, nominal form lebih besar, pesan validasi lebih jelas.
- Versi 1.2.0+3; skema Supabase + RLS di `docs/supabase_schema.sql`.

## Belum dikerjakan
- **Sinkronisasi Supabase**: belum ada `supabase_flutter`, URL/anon key, maupun SyncService. Fondasinya sudah ada (ID unik, `updatedAt`, tombstone, `syncState`, skema+RLS), tetapi perlu keputusan: pakai Supabase Auth untuk menggantikan login lokal (wajib agar RLS berfungsi).
- Penggantian penyimpanan JSON SharedPreferences ke SQLite/Drift.
- Token/sesi di penyimpanan aman (`flutter_secure_storage`), hapus akun, audit logout/sesi.
- Deteksi koneksi (`connectivity_plus`); saat ini antrean upload dicek tiap 60 detik selama aplikasi terbuka dan saat aplikasi dibuka.
- Anggaran, ekspor CSV/PDF, unit test akurasi perhitungan.
