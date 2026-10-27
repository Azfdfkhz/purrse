# PurssApp 1.3.0 — Supabase Auth + Sinkronisasi, FCM, Layout

> **Belum dikompilasi dan belum diuji.** Sandbox tempat kode ini ditulis tidak punya Flutter SDK
> maupun akses pub.dev. Urutan pertama di mesin Anda:
> `flutter pub get && flutter analyze && flutter run`. Perbaiki bila ada galat kompilasi kecil
> (saya hanya bisa memeriksa kurung/sintaks dan menelusuri tipe secara manual).

## Langkah wajib sebelum dicoba
1. Jalankan **seluruh** `docs/supabase_schema.sql` di Supabase › SQL Editor.
2. Supabase › Authentication › Providers › Email: lihat `docs/SUPABASE_SETUP.md` (soal "Confirm email").
3. Untuk FCM: ikuti `docs/FCM_SETUP.md` (butuh `google-services.json` Firebase asli — file yang ada di
   repo adalah klien OAuth, bukan konfigurasi Firebase, jadi FCM otomatis nonaktif sampai diganti).
4. Jika `pub get` gagal soal versi `firebase_core`/`firebase_messaging`, jalankan `flutter pub upgrade`
   atau sesuaikan versi di `pubspec.yaml` dengan Flutter Anda.

## 1. Supabase Auth + sinkronisasi + RLS
- Login/daftar kini lewat `AuthService` (Supabase Auth). ID akun lokal = `auth.uid()`; itu yang membuat
  RLS (`auth.uid() = user_id`) berlaku untuk data transaksi dan kategori.
- Akun lokal tetap ada sebagai cermin (offline, profil, avatar). Aplikasi tetap bisa dibuka tanpa internet.
- `SyncService`: pull lalu push; konflik last-write-wins per baris (`updated_at`); kursor pull memakai
  `server_ts` (jam server); hapus = tombstone; berjalan saat dibuka, saat ada perubahan (jeda 5 dtk),
  tiap 3 menit, dan saat aplikasi kembali ke latar depan. Foto bukti tetap di Google Drive,
  yang disinkronkan hanya `drive_file_id` (perangkat lain bisa memuat foto dari Drive bila akun Drive sama).
- Status sinkron + tombol "Sinkronkan sekarang" ada di Akun › Data.
- Ganti password mengubah password Supabase dan lokal sekaligus.

### Migrasi akun lokal lama (otomatis, tanpa menghapus data)
| Kondisi saat login | Hasil |
|---|---|
| Akun lokal + email belum ada di cloud | Dibuat akun cloud dengan email & password yang sama; seluruh transaksi/kategori dipindah ke ID baru dan dikirim ke cloud. |
| Akun lokal + email sudah ada di cloud, password cloud sama | Login cloud, data lokal digabung (per ID, versi `updatedAt` terbaru menang). Kategori bawaan kembar (nama sama) digabung, bukan digandakan. |
| Akun lokal + email sudah ada di cloud, **password berbeda** | Tetap masuk **mode lokal** (data aman, tidak ada yang hilang) + pesan jelas. Sinkron aktif setelah masuk dengan password cloud / reset password. |
| Offline | Masuk mode lokal; sinkron menyusul. |
| Perangkat baru, akun hanya di cloud | Akun lokal dibuat dari akun cloud, data ditarik. |
| Daftar dengan email yang sudah dipakai | Ditolak dengan pesan "Email sudah terdaftar". |

Catatan perilaku yang berubah:
- **Restore backup** sekarang konsisten dengan sync: transaksi yang ada di perangkat tapi tidak ada di
  backup diberi tombstone (bukan dihapus diam-diam), dan data hasil restore menang atas versi cloud.
- Kategori kini dihapus lunak (tombstone) agar penghapusan tersinkron.
- Pendaftaran butuh internet (akun cloud dibuat saat itu juga).

## 2. FCM (sisi aplikasi)
- `FcmService`: init aman bila Firebase belum dikonfigurasi, minta izin sekali setelah login, simpan token
  ke `device_tokens` lewat RPC `register_device_token`, lepas token saat logout, tampilkan pesan saat
  aplikasi terbuka, ketuk notifikasi membuka layar (`data.payload` = `backup` atau `home`).
- Gradle: plugin `google-services` diterapkan **hanya** bila `google-services.json` berisi `project_info`.
- **Tidak termasuk:** server pengirim pesan (lihat `docs/FCM_SETUP.md` untuk gambaran), folder `ios/`
  (tidak ada di zip; perlu `flutter create --platforms=ios .` + APNs).

## 3. Layout
- **Auth:** satu kerangka bersama (`AuthScaffold`) — bisa digulir (layar kecil/font besar/keyboard), lebar
  maksimum di layar lebar, tombol Enter berpindah kolom/kirim, autofill, tombol lihat password dengan
  label, banner galat dengan ikon (tidak mengandalkan warna), tautan "Lupa password?" (sebelumnya
  layarnya ada tapi tidak bisa dibuka dari login), layar pilihan tidak lagi bisa overflow.
- **Transaksi:** filter tanggal + kategori dalam satu baris (tanggal tidak lagi tersembunyi di AppBar),
  ringkasan jumlah & total, daftar dikelompokkan per hari (Hari ini/Kemarin/tanggal + total hari),
  kartu dengan foto rasio tetap, nominal tidak lagi memakai warna aksen pastel (kontras), status upload
  dengan warna yang terbaca di Dark Mode, target ketuk ≥ 48 dp, ruang bawah agar tidak tertutup navbar,
  empty state berbeda untuk "belum ada foto" vs "filter tidak cocok".
- **Profil:** judul "Akun", kartu identitas (foto, nama, email, status cloud), menu dikelompokkan dalam
  kartu (Preferensi / Data / Keamanan), ikon lonceng dekoratif yang tidak berfungsi dihapus, tombol Keluar
  terpisah dengan warna aman untuk Dark Mode, baris status sinkronisasi.

## Belum dikerjakan / perlu Anda
- Kompilasi & uji di perangkat (checklist QA bagian 8): font besar, layar kecil, Dark Mode tiap layar,
  izin notifikasi Android 13+ dan iOS, alur migrasi dengan data lama sungguhan.
- Layout belum pernah dilihat di layar; kemungkinan perlu penyesuaian spasi/kontras setelah dicoba.
- Reset password lewat email butuh konfigurasi deep link/redirect URL di Supabase agar tautannya
  kembali ke aplikasi.
- Pengirim push (Edge Function/backend), `flutter_secure_storage` untuk sesi, hapus akun, unit test merge.
