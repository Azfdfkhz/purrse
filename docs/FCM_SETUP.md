# Setup FCM (push notification)

Aplikasi sudah siap menerima push; yang Anda siapkan: proyek Firebase, konfigurasi platform, dan pengirim.

## Android
1. Firebase Console › buat proyek › tambah app Android dengan package `com.example.finance_app`
   (atau package baru bila `applicationId` diganti).
2. Unduh **google-services.json** Firebase dan timpa `android/app/google-services.json`.
   (File saat ini hanya berisi klien OAuth; selama belum diganti, FCM nonaktif dan build tetap aman.)
3. Build ulang. Saat pertama login, aplikasi meminta izin notifikasi (Android 13+).

## iOS
Zip tidak berisi folder `ios/`. Jalankan `flutter create --platforms=ios .`, tambahkan
`GoogleService-Info.plist` ke Runner, aktifkan capability *Push Notifications* + *Background Modes › Remote
notifications*, dan unggah kunci APNs (.p8) di Firebase › Cloud Messaging.

## Pengirim (di luar aplikasi)
Token perangkat tersimpan di `public.device_tokens (token, user_id, platform)`. Kirim lewat **FCM HTTP v1**
dari server tepercaya (mis. Supabase Edge Function dengan service account Firebase di *secrets*):
```json
{ "message": { "token": "<token>",
  "notification": { "title": "Judul", "body": "Isi (jangan memuat nominal/data keuangan)" },
  "data": { "payload": "backup" } } }
```
`data.payload`: `backup` membuka Backup & Restore, `home` membuka aplikasi. Hapus token dari tabel bila FCM
membalas `UNREGISTERED`. Jangan menaruh service account atau `service_role` di aplikasi.
