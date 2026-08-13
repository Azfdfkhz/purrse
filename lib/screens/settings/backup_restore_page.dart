import 'package:flutter/material.dart';

import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() =>
      _BackupRestorePageState();
}

class _BackupRestorePageState
    extends State<BackupRestorePage> {
  bool _loading = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();

    _connected =
        GoogleDriveService.instance.isSignedIn;
  }

  Future<void> _connectGoogleDrive() async {
    setState(() => _loading = true);

    try {
      final account =
      await GoogleDriveService.instance.signIn();

      if (!mounted) return;

      if (account != null) {
        setState(() {
          _connected = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terhubung sebagai ${account.email}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghubungkan Google Drive: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _backup() async {
    setState(() => _loading = true);

    try {
      if (!GoogleDriveService.instance.isSignedIn) {
        await GoogleDriveService.instance.signIn();
      }

      await BackupService.instance
          .backupToGoogleDrive();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup berhasil disimpan ke Google Drive.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup gagal: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Data'),
          content: const Text(
            'Data lokal akan diganti dengan data dari Google Drive. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      if (!GoogleDriveService.instance.isSignedIn) {
        await GoogleDriveService.instance.signIn();
      }

      await BackupService.instance
          .restoreFromGoogleDrive();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data berhasil di-restore.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore gagal: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _disconnect() async {
    await GoogleDriveService.instance.signOut();

    if (!mounted) return;

    setState(() {
      _connected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Google Drive
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                            primary.withOpacity(.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_outlined,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Drive',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Google Drive digunakan sebagai tempat backup data.',
                                style: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (!_connected)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading
                              ? null
                              : _connectGoogleDrive,
                          icon: const Icon(
                            Icons.login,
                          ),
                          label: const Text(
                            'Hubungkan Google Drive',
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(14),
                            decoration:
                            BoxDecoration(
                              color: Colors.green
                                  .withOpacity(.10),
                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Google Drive terhubung',
                                  style: TextStyle(
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : _disconnect,
                              child: const Text(
                                'Putuskan Google Drive',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Backup
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Backup Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Simpan transaksi, kategori, dan pengaturan aplikasi ke Google Drive.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                        _loading ? null : _backup,
                        icon: const Icon(
                          Icons.backup,
                        ),
                        label: const Text(
                          'Backup Sekarang',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Restore
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface,
                  borderRadius:
                  BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Restore Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kembalikan data dari backup Google Drive ke aplikasi.',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                        _loading ? null : _restore,
                        icon: const Icon(
                          Icons.restore,
                        ),
                        label: const Text(
                          'Restore Data',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                'Data utama tetap tersimpan di perangkat. Google Drive hanya digunakan sebagai backup.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(.6),
                ),
              ),
            ],
          ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(.25),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}