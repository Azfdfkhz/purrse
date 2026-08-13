# Kantong - Aplikasi Pengatur Keuangan (Flutter)

Aplikasi pencatat pengeluaran pribadi. Semua data (akun, kategori, pengeluaran)
disimpan **lokal di memori HP** menggunakan `shared_preferences` — tidak perlu
server/internet, dan data akan hilang jika aplikasi di-uninstall.

## Fitur yang sudah dibuat
- Splash screen
- Alur autentikasi: pilih Daftar/Masuk -> Registrasi -> Login (disimpan lokal)
- Beranda: kartu ringkasan pengeluaran bulan berjalan (bisa ganti bulan),
  diagram donat + legenda kategori, daftar pengeluaran terbaru (scrollable di
  dalam card, halaman utama sendiri tidak perlu discroll)
- Navbar bawah custom (Beranda, Bukti, tombol tambah mengambang, Laporan, Profile)
- Form tambah pengeluaran (bottom sheet): jumlah, kategori (bisa tambah kategori
  baru), tanggal, deskripsi, upload bukti foto (opsional)
- Halaman Transaksi: placeholder ("Segera hadir") — sesuai permintaan,
  menyusul dibuat belakangan
- Halaman Laporan — 2 tampilan sesuai desain, bisa ditoggle lewat pill "Hari"/"Bulan":
  - **Hari**: kalender grid (lingkaran per tanggal, ada titik penanda hari yang
    ada transaksinya) + daftar pengeluaran pada tanggal yang dipilih
  - **Bulan**: grafik batang total pengeluaran per bulan (Jan-Des, bulan
    terpilih ditandai warna lebih tegas) + ringkasan pengeluaran per kategori
    untuk bulan yang dipilih
  - Navigasi bulan/tahun pakai tombol panah kiri-kanan di kedua tampilan
  - Pill pertama ("Hari"/"Bulan") tap membuka submenu pilih Hari atau Bulan
  - Pill kedua ("Calender"/"Data") tap membuka submenu pilih tampilan
    **Calender** (grid kalender / grafik batang) atau **Data** (daftar
    tanggal+total / daftar bulan+total dalam bentuk list, bisa ditap untuk
    memilih tanggal atau bulan)
- Halaman Akun (Profile) — sesuai desain terbaru:
  - Header dengan foto profil bisa diganti langsung lewat ikon kamera
  - Tombol "Edit Profile" untuk ubah username & foto
  - **Tampilan**: pilih warna aksen (dipakai di kartu Beranda) dari beberapa
    preset warna soft, tersimpan otomatis
  - **Kategori Pengeluaran**: kelola kategori (tambah, edit nama, ganti ikon
    dari daftar pilihan, ganti warna, hapus)
  - **Keamanan**: ubah password akun (perlu password lama)
  - **Keluar**: logout dengan konfirmasi

## Cara menjalankan
Folder ini hanya berisi kode Dart (`lib/`) dan `pubspec.yaml`. Untuk
menjalankannya kamu perlu scaffold proyek Flutter penuh (folder android/ios)
di komputer kamu sendiri karena environment ini tidak memiliki Flutter SDK:

1. Pastikan Flutter SDK sudah terpasang (`flutter doctor`).
2. Buat proyek baru:
   ```bash
   flutter create kantong_app
   cd kantong_app
   ```
3. Salin isi folder `lib/` dan file `pubspec.yaml` dari paket ini,
   menimpa yang ada di `kantong_app/`.
4. Ambil semua dependency:
   ```bash
   flutter pub get
   ```
5. Jalankan:
   ```bash
   flutter run
   ```

## Catatan tambahan
- **image_picker**: untuk upload bukti foto. Di iOS tambahkan izin berikut ke
  `ios/Runner/Info.plist`:
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Aplikasi membutuhkan akses galeri untuk mengunggah bukti pengeluaran</string>
  ```
  Di Android umumnya tidak perlu konfigurasi tambahan untuk Android 13+.
- **google_fonts**: mengunduh font Baloo2 & Nunito saat pertama kali dijalankan
  (butuh koneksi internet sekali). Jika ingin 100% offline, ganti dengan font
  bawaan sistem di `lib/theme/app_theme.dart`.
- Password akun disimpan apa adanya (plain text) di penyimpanan lokal karena ini
  murni demo offline tanpa server — untuk produksi sebaiknya di-hash.
- Struktur folder:
  ```
  lib/
    main.dart
    theme/            -> warna & tipografi (AppColors, AppTheme)
    models/            -> UserModel, ExpenseModel, CategoryModel
    services/          -> StorageService (semua logic penyimpanan lokal)
    utils/             -> formatter Rupiah & tanggal
    widgets/           -> komponen reusable (text field, coming soon)
    screens/
      splash_screen.dart
      auth/            -> AuthChoiceScreen, RegisterScreen, LoginScreen
      shell/           -> NavbarShell (bottom nav + FAB tambah)
      home/            -> BerandaScreen
      expense/         -> AddExpenseModal
      profile/         -> ProfileScreen (Akun), AppearanceScreen,
                           CategoryManagementScreen, ChangePasswordScreen,
                           EditProfileScreen
      laporan/         -> LaporanScreen (toggle Hari/Bulan)
      placeholder/     -> TransaksiScreen
  ```

## Selanjutnya
Halaman **Transaksi** (lengkap) belum diimplementasikan penuh sesuai instruksi
("nanti nyusul") — tinggal isi konten di
`lib/screens/placeholder/transaksi_screen.dart` ketika designnya sudah siap.
