# Setup Supabase untuk PurssApp 1.3.0

1. **Skema:** SQL Editor › tempel & jalankan seluruh `docs/supabase_schema.sql` (aman diulang).
2. **Email konfirmasi** (Authentication › Providers › Email › *Confirm email*):
   - **Nonaktif (disarankan untuk migrasi mulus):** pendaftaran & penautan akun lama langsung aktif.
   - **Aktif:** daftar/penautan menampilkan "cek email untuk konfirmasi"; pengguna harus konfirmasi lalu masuk lagi.
     Data lokal aman selama itu.
3. **Kunci API:** `SupabaseService.supabaseUrl` / `supabaseAnonKey`. Kunci *publishable/anon* memang
   dirancang publik; keamanan data dijaga RLS. Jangan pernah memasukkan `service_role` ke aplikasi.
4. **Reset password:** tambahkan redirect URL/deep link aplikasi di Authentication › URL Configuration
   bila ingin tautan email kembali ke aplikasi. Setelah reset, login berikutnya otomatis memperbarui
   password lokal.
5. **Uji RLS:** dengan dua akun berbeda, pastikan `select * from expenses` dari klien akun A tidak
   mengembalikan baris akun B.
